// ImmersiveView.swift (Updated with CSV loading)
import SwiftUI
import RealityKit
import simd
import Combine

// MARK: - Data Structures
struct Pose {
    var transforms: [String: Transform]
}

struct Keyframe {
    var time: TimeInterval
    var pose: Pose
}

// MARK: - Main View
struct ImmersiveView: View {
    @EnvironmentObject var viewModel: ViewModel
    @State private var subscription: AnyCancellable?
    @State private var modelEntity: ModelEntity?
    @State private var jointIndices: [String: Int] = [:]
    @State private var animationKeyframes: [Keyframe] = []
    
    var body: some View {
        RealityView { content, attachments in
            do {
                let model = try await ModelEntity(named: "lowpoly")
                model.position = [0, 1.2, -2]
                let bounds = model.visualBounds(relativeTo: nil)
                let bottomY = bounds.center.y - bounds.extents.y / 2
                let scaleY = model.scale.y
                model.position.y = -bottomY * scaleY
                
                model.scale = [0.015,0.015,0.015]
                
                // --- LIGHTING ---
                let lightEntity = DirectionalLight()
                lightEntity.position = SIMD3<Float>(20,20,20)
                lightEntity.look(at: model.position, from: lightEntity.position, relativeTo: nil)
                lightEntity.light.intensity = 5000
                content.add(lightEntity)
                
                content.add(model)
                
                // Add the controls attachment
                if let controlsEntity = attachments.entity(for: "controls") {
                    controlsEntity.position = [0.8, 1.2, -2]
                    content.add(controlsEntity)
                }
                
                self.modelEntity = model
                
                // Setup animation from CSV
                Task {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    await setupAnimationFromCSV(model: model)
                }
                
            } catch {
                print("Failed to load model: \(error)")
            }
        } attachments: {
            Attachment(id: "controls") {
                PlaybackControlsView()
            }
        }
    }
    
    private func easeInOutBack(_ t: Float) -> Float {
        let c1: Float = 1.70158
        let c2 = c1 * 1.525
        
        if t < 0.5 {
            return (pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
        } else {
            return (pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
        }
    }
    
    @MainActor
    private func setupAnimationFromCSV(model: ModelEntity) async {
        do {
            // Load keyframes from CSV
            animationKeyframes = try await CSVAnimationLoader.loadAnimation(from: "hand_data_pivoted")
            
            print("Loaded \(animationKeyframes.count) keyframes from CSV")
            
            // Set total time based on last keyframe
            if let lastKeyframe = animationKeyframes.last {
                viewModel.totalTime = lastKeyframe.time
                print("Total animation time: \(lastKeyframe.time) seconds")
            }
            
            guard let scene = model.scene else {
                print("ERROR: Scene not found on model. Retrying in 0.1s.")
                Task {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    await setupAnimationFromCSV(model: model)
                }
                return
            }
            
            // Build joint indices
            jointIndices.removeAll()
            var startingPoseTransforms: [String: Transform] = [:]
            
            for jointName in requiredJoints {
                if let index = model.jointNames.firstIndex(of: jointName) {
                    jointIndices[jointName] = index
                    startingPoseTransforms[jointName] = model.jointTransforms[index]
                }
            }

            // Set first keyframe to starting pose if needed
            if !animationKeyframes.isEmpty && animationKeyframes[0].time == 0 {
                // Merge starting pose with first keyframe
                for (joint, transform) in startingPoseTransforms {
                    if animationKeyframes[0].pose.transforms[joint] == nil {
                        animationKeyframes[0].pose.transforms[joint] = transform
                    }
                }
            }
            
            // Subscribe to scene updates
            self.subscription = scene.subscribe(to: SceneEvents.Update.self) { event in
                self.viewModel.updateTime(event.deltaTime)
                let loopedTime = self.viewModel.currentTime
                
                guard let (prevKeyframe, nextKeyframe) = self.findKeyframes(for: loopedTime) else { return }
                
                let timeInRange = loopedTime - prevKeyframe.time
                let rangeDuration = nextKeyframe.time - prevKeyframe.time
                let linearT = rangeDuration > 0 ? Float(timeInRange / rangeDuration) : 0
                let easedT = self.easeInOutBack(linearT)
                
                // Apply interpolated transforms
                for (jointName, jointIndex) in self.jointIndices {
                    guard let prevTransform = prevKeyframe.pose.transforms[jointName],
                          let nextTransform = nextKeyframe.pose.transforms[jointName] else { continue }
                    
                    let interpolatedRotation = simd_slerp(prevTransform.rotation, nextTransform.rotation, easedT)
                    
                    var newTransform = model.jointTransforms[jointIndex]
                    newTransform.rotation = interpolatedRotation
                    
                    model.jointTransforms[jointIndex] = newTransform
                }
            } as! AnyCancellable
            
            print("CSV Animation started successfully!")
            
        } catch {
            print("Failed to load CSV animation: \(error)")
            print("Falling back to hardcoded animation")
            // Fall back to hardcoded animation
            animationKeyframes = getHardcodedKeyframes()
            await setupAnimationWithKeyframes(model: model)
        }
    }
    
    @MainActor
    private func setupAnimationWithKeyframes(model: ModelEntity) async {
        guard let scene = model.scene else { return }
        
        jointIndices.removeAll()
        var startingPoseTransforms: [String: Transform] = [:]
        
        for jointName in requiredJoints {
            if let index = model.jointNames.firstIndex(of: jointName) {
                jointIndices[jointName] = index
                startingPoseTransforms[jointName] = model.jointTransforms[index]
            }
        }

        if !animationKeyframes.isEmpty {
            animationKeyframes[0].pose = Pose(transforms: startingPoseTransforms)
        }
        
        self.subscription = scene.subscribe(to: SceneEvents.Update.self) { event in
            self.viewModel.updateTime(event.deltaTime)
            let loopedTime = self.viewModel.currentTime
            
            guard let (prevKeyframe, nextKeyframe) = self.findKeyframes(for: loopedTime) else { return }
            
            let timeInRange = loopedTime - prevKeyframe.time
            let rangeDuration = nextKeyframe.time - prevKeyframe.time
            let linearT = rangeDuration > 0 ? Float(timeInRange / rangeDuration) : 0
            let easedT = self.easeInOutBack(linearT)
            
            for (jointName, jointIndex) in self.jointIndices {
                guard let prevTransform = prevKeyframe.pose.transforms[jointName],
                      let nextTransform = nextKeyframe.pose.transforms[jointName] else { continue }
                
                let interpolatedRotation = simd_slerp(prevTransform.rotation, nextTransform.rotation, easedT)
                
                var newTransform = model.jointTransforms[jointIndex]
                newTransform.rotation = interpolatedRotation
                
                model.jointTransforms[jointIndex] = newTransform
            }
        } as! AnyCancellable
    }

    private func findKeyframes(for time: TimeInterval) -> (Keyframe, Keyframe)? {
        guard !animationKeyframes.isEmpty else { return nil }
        
        if time < animationKeyframes.first?.time ?? 0 {
            return (animationKeyframes.first!, animationKeyframes.first!)
        }
        
        for i in 0..<(animationKeyframes.count - 1) {
            let current = animationKeyframes[i]
            let next = animationKeyframes[i + 1]
            if time >= current.time && time <= next.time {
                return (current, next)
            }
        }
        
        return (animationKeyframes.last!, animationKeyframes.last!)
    }
    
    // Fallback hardcoded keyframes
    private func getHardcodedKeyframes() -> [Keyframe] {
        return [
            Keyframe(time: 0.5, pose: Pose(transforms: [:])),
            Keyframe(time: 2, pose: Pose(transforms: [
                rightShoulderName: Transform(rotation: simd_quatf(angle: 0.8, axis: [0, 0, -1])),
                rightArmName: Transform(rotation: simd_quatf(angle: -1.2, axis: [0,1,0])),
                rightForearmName: Transform(rotation: simd_quatf(angle: 1.1, axis: [1,0,0])),
            ])),
            Keyframe(time: 14.5, pose: Pose(transforms: [
                rightShoulderName: Transform(rotation: simd_quatf(angle: 1.5, axis: [0, 0, -1])),
                rightArmName: Transform(rotation: simd_quatf(angle: -0.1, axis: [0,1,0])),
            ]))
        ]
    }
}

// MARK: - Joint Names
let rightShoulderName = "n9/n10/n14"
let leftShoulderName = "n9/n10/n33"
let rightArmName = "n9/n10/n14/n15"
let rightForearmName = "n9/n10/n14/n15/n16"
let rightHandName = "n9/n10/n14/n15/n16/n17"
let headName = "n52"
let rightMiddle1Name = "n9/n10/n14/n15/n16/n17/n18"
let rightMiddle2Name = "n9/n10/n14/n15/n16/n17/n18/n19"
let rightRing1Name = "n9/n10/n14/n15/n16/n17/n21"
let rightRing2Name = "n9/n10/n14/n15/n16/n17/n21/n22"
let rightPinky1Name = "n9/n10/n14/n15/n16/n17/n24"
let rightPinky2Name = "n9/n10/n14/n15/n16/n17/n24/n25"
let rightIndex1Name = "n9/n10/n14/n15/n16/n17/n27"
let rightIndex2Name = "n9/n10/n14/n15/n16/n17/n27/n28"
let rightThumb1Name = "n9/n10/n14/n15/n16/n17/n30"
let rightThumb2Name = "n9/n10/n14/n15/n16/n17/n30/n31"

let requiredJoints = [
    rightShoulderName, leftShoulderName, rightArmName, rightForearmName, rightHandName,
    rightMiddle1Name, rightMiddle2Name, rightRing1Name, rightRing2Name,
    rightPinky1Name, rightPinky2Name, rightIndex1Name, rightIndex2Name,
    rightThumb1Name, rightThumb2Name
]
