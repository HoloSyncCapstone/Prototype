// ImmersiveView.swift (Integrated Version)
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
    
    var body: some View {
        ZStack {
            // Reality content
            RealityView { content in
                do {
                    let model = try await ModelEntity(named: "lowpoly")
                    model.position = [0, 1.2, -2]
                    let bounds = model.visualBounds(relativeTo: nil)
                    let bottomY = bounds.center.y - bounds.extents.y / 2
                    let scaleY = model.scale.y
                    model.position.y = -bottomY * scaleY
                    
                    model.scale = [0.015,0.015,0.015]
                    
                    // --- LIGHTING: Add a directional light pointing at the human ---
                    let lightEntity = DirectionalLight()
                    // Place the light above and in front of the model
                    lightEntity.position = SIMD3<Float>(20,20,20)
                    // Point the light towards the model's position
                    lightEntity.look(at: model.position, from: lightEntity.position, relativeTo: nil)
                    lightEntity.light.intensity = 5000 // Adjust intensity as needed
                    content.add(lightEntity)
                    
                    // --- END LIGHTING ---
                    
                    content.add(model)
                    
                    // Store model reference
                    self.modelEntity = model
                    
                    // Setup animation after a small delay to ensure the scene is ready
                    Task {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                        await setupAnimation(model: model)
                    }
                    
                } catch {
                    print("Failed to load model: \(error)")
                }
            }
            
            // UI overlay
            VStack {
                Spacer()
                PlaybackControlsView()
                    .offset(x: -10, y: 50)
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
    private func setupAnimation(model: ModelEntity) async {
        guard let scene = model.scene else {
            print("ERROR: Scene not found on model. Retrying in 0.1s.")
            // Retry if the scene isn't ready yet
            Task {
                try await Task.sleep(nanoseconds: 100_000_000)
                await setupAnimation(model: model)
            }
            return
        }
        
        var startingPoseTransforms: [String: Transform] = [:]
        jointIndices.removeAll()
        
        for jointName in requiredJoints {
            if let index = model.jointNames.firstIndex(of: jointName) {
                jointIndices[jointName] = index
                startingPoseTransforms[jointName] = model.jointTransforms[index]
            }
        }

        if !animationKeyframes.isEmpty {
            animationKeyframes[0].pose = Pose(transforms: startingPoseTransforms)
        }
        
        // Subscribe to scene updates
        self.subscription = scene.subscribe(to: SceneEvents.Update.self) { event in
            // Update time in ViewModel
            self.viewModel.updateTime(event.deltaTime)
            
            // Use the ViewModel's current time for animation
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
        
        print("Animation started successfully!")
    }

    private func findKeyframes(for time: TimeInterval) -> (Keyframe, Keyframe)? {
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
}

// MARK: - Joint Names & Keyframes (Preserve your exact data)
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

let restPose = Pose(transforms: [:])

// NOTE: Replace this array with your full keyframe data
var animationKeyframes: [Keyframe] = [
    Keyframe(time: 0.5, pose: restPose),
    // Example keyframes (replace with your full animation data):
    Keyframe(time: 2, pose: Pose(transforms: [
        rightShoulderName: Transform(rotation: simd_quatf(angle: 0.8, axis: [0, 0, -1])),
        rightArmName: Transform(rotation: simd_quatf(angle: -1.2, axis: [0,1,0])),
        rightForearmName: Transform(rotation: simd_quatf(angle: 1.1, axis: [1,0,0])),
        rightHandName: Transform(rotation: simd_quatf(angle: 0.2, axis: [1,0,0])),
        rightMiddle1Name: Transform(rotation: simd_quatf(angle: 1.4, axis: [0,0,-1])),
        rightMiddle2Name: Transform(rotation: simd_quatf(angle: 2, axis: [0,0,-1])),
        rightRing1Name: Transform(rotation: simd_quatf(angle: 1.4, axis: [0,0,-1])),
        rightRing2Name: Transform(rotation: simd_quatf(angle: 2.0, axis: [0,0,-1])),
        rightPinky1Name: Transform(rotation: simd_quatf(angle: 1.4, axis: [0,0,-1])),
        rightPinky2Name: Transform(rotation: simd_quatf(angle: 2.0, axis: [0,0,-1])),
        rightIndex1Name: Transform(rotation: simd_quatf(angle: 1.2, axis: [0,0,-1])),
        rightIndex2Name: Transform(rotation: simd_quatf(angle: 2, axis: [0,0,-1])),
        rightThumb1Name: Transform(rotation: simd_quatf(angle: 1.2, axis: [0,0,-1])),
        rightThumb2Name: Transform(rotation: simd_quatf(angle: 1, axis: [-1,0,0])),
    ])),
    
    //pinky/index extended
    Keyframe(time: 7, pose: Pose(transforms: [
        rightShoulderName: Transform(rotation: simd_quatf(angle: 0.8, axis: [0, 0, -1])),
        rightArmName: Transform(rotation: simd_quatf(angle: -1.3, axis: [0,1,0])),
        rightForearmName: Transform(rotation: simd_quatf(angle: 1.3, axis: [1,0,0])),
        // --- Fingers ---
        rightMiddle1Name: Transform(rotation: simd_quatf(angle: 1.4, axis: [0,0,-1])),
        rightMiddle2Name: Transform(rotation: simd_quatf(angle: 2, axis: [0,0,-1])),
        rightRing1Name: Transform(rotation: simd_quatf(angle: 1.4, axis: [0,0,-1])),
        rightRing2Name: Transform(rotation: simd_quatf(angle: 2.0, axis: [0,0,-1])),
        rightPinky1Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightPinky2Name: Transform(rotation: simd_quatf(angle: -0.1, axis: [1,0,0])),
        rightIndex1Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightIndex2Name: Transform(rotation: simd_quatf(angle: -0.1, axis: [1,0,0])),
        rightThumb1Name: Transform(rotation: simd_quatf(angle: 1.2, axis: [0,0,-1])),
        rightThumb2Name: Transform(rotation: simd_quatf(angle: 0.7, axis: [-1,0,0])),
    ])),
    
    
        
    Keyframe(time: 14.5, pose: Pose(transforms: [
        // Return arm to a near-neutral position to blend with the start pose
        rightShoulderName: Transform(rotation: simd_quatf(angle: 1.5, axis: [0, 0, -1])),
        rightArmName: Transform(rotation: simd_quatf(angle: -0.1, axis: [0,1,0])),
        rightForearmName: Transform(rotation: simd_quatf(angle: 0.1, axis: [1,0,0])),
        rightHandName: Transform(rotation: simd_quatf(angle: 0, axis: [0,1,0])),
        // --- Fingers (open and relaxed) ---
        rightMiddle1Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightMiddle2Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightRing1Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightRing2Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightPinky1Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightPinky2Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightIndex1Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightIndex2Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightThumb1Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [1,0,0])),
        rightThumb2Name: Transform(rotation: simd_quatf(angle: 0.0, axis: [-1,0,0])),
    ]))
]

