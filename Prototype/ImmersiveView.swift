// ImmersiveView.swift - Integrated with Object & Device Pose
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
    
    // Object & Device tracking
    @State private var devicePoses: [PoseSample] = []
    @State private var objectPoses: [PoseSample] = []
    @State private var deviceEntity: ModelEntity?
    @State private var objectEntities: [String: ModelEntity] = [:] // anchorID -> entity
    @State private var objectRootEntity = ModelEntity()
    
    var body: some View {
        RealityView { content, attachments in
            do {
                // Load avatar model
                let model = try await ModelEntity(named: "lowpoly")
                model.position = [0, 1.2, -2]
                let bounds = model.visualBounds(relativeTo: nil)
                let bottomY = bounds.center.y - bounds.extents.y / 2
                let scaleY = model.scale.y
                model.position.y = -bottomY * scaleY
                model.scale = [0.015, 0.015, 0.015]
                
                // Lighting
                let lightEntity = DirectionalLight()
                lightEntity.position = SIMD3<Float>(20, 20, 20)
                lightEntity.look(at: model.position, from: lightEntity.position, relativeTo: nil)
                lightEntity.light.intensity = 5000
                content.add(lightEntity)
                
                content.add(model)
                
                // Add playback controls attachment
                if let controlsEntity = attachments.entity(for: "controls") {
                    controlsEntity.position = [0.8, 1.2, -2]
                    content.add(controlsEntity)
                }
                
                self.modelEntity = model
                
                // Create device cube (white)
                let headsetBox = MeshResource.generateBox(size: [0.20, 0.08, 0.10])
                var headsetMat = PhysicallyBasedMaterial()
                headsetMat.baseColor = .init(tint: .white)
                let deviceCube = ModelEntity(mesh: headsetBox, materials: [headsetMat])
                deviceCube.name = "deviceCube"
                content.add(deviceCube)
                self.deviceEntity = deviceCube
                
                // --- Prepare objectRootEntity for all object boxes
                objectRootEntity.name = "objectRoot"
                content.add(objectRootEntity)
                
                // Setup animation from CSV (no more passing content)
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
            // Load all three datasets
            print("📦 Loading datasets...")
            
            devicePoses = PoseCSVLoader.load(resource: "device_pose_data")
            print("✅ Loaded \(devicePoses.count) device poses")
            
            objectPoses = PoseCSVLoader.load(resource: "object_pose_data")
            print("✅ Loaded \(objectPoses.count) object poses")
            
            animationKeyframes = try await CSVAnimationLoader.loadAnimation(from: "hand_data_pivoted")
            print("✅ Loaded \(animationKeyframes.count) hand keyframes")
            
            // Create object entities for each unique anchorID (add as children of objectRootEntity)
            let uniqueAnchorIDs = Set(objectPoses.compactMap { $0.anchorID })
            print("📍 Found \(uniqueAnchorIDs.count) unique objects: \(uniqueAnchorIDs)")
            
            var newObjectEntities: [String: ModelEntity] = [:]
            objectRootEntity.children.removeAll()
            
            for (index, anchorID) in uniqueAnchorIDs.enumerated() {
                let objectBox = MeshResource.generateBox(size: [0.10, 0.10, 0.10])
                var objectMat = PhysicallyBasedMaterial()
                
                // Different color for each object
                let colors: [UIColor] = [.red, .green, .blue, .yellow, .cyan, .magenta, .orange]
                objectMat.baseColor = .init(tint: colors[index % colors.count])
                
                let objectEntity = ModelEntity(mesh: objectBox, materials: [objectMat])
                objectEntity.name = "object_\(anchorID)"
                objectRootEntity.addChild(objectEntity)
                
                newObjectEntities[anchorID] = objectEntity
            }
            
            objectEntities = newObjectEntities
            
            // Set total time based on last hand keyframe
            if let lastKeyframe = animationKeyframes.last {
                viewModel.totalTime = lastKeyframe.time
                print("⏱️ Total animation time: \(lastKeyframe.time) seconds")
            }
            
            guard let scene = model.scene else {
                print("ERROR: Scene not found on model. Retrying in 0.1s.")
                Task {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    await setupAnimationFromCSV(model: model)
                }
                return
            }
            
            // Build joint indices for hand animation
            jointIndices.removeAll()
            var startingPoseTransforms: [String: Transform] = [:]
            
            for jointName in requiredJoints {
                if let index = model.jointNames.firstIndex(of: jointName) {
                    jointIndices[jointName] = index
                    startingPoseTransforms[jointName] = model.jointTransforms[index]
                }
            }

            // Merge starting pose with first keyframe if needed
            if !animationKeyframes.isEmpty && animationKeyframes[0].time == 0 {
                for (joint, transform) in startingPoseTransforms {
                    if animationKeyframes[0].pose.transforms[joint] == nil {
                        animationKeyframes[0].pose.transforms[joint] = transform
                    }
                }
            }
            
            // Subscribe to scene updates
            self.subscription = scene.subscribe(to: SceneEvents.Update.self) { event in
                self.viewModel.updateTime(event.deltaTime)
                let currentTime = self.viewModel.currentTime
                
                // ========== UPDATE HAND ANIMATION ==========
                guard let (prevKeyframe, nextKeyframe) = self.findKeyframes(for: currentTime) else { return }
                
                let timeInRange = currentTime - prevKeyframe.time
                let rangeDuration = nextKeyframe.time - prevKeyframe.time
                let linearT = rangeDuration > 0 ? Float(timeInRange / rangeDuration) : 0
                let easedT = self.easeInOutBack(linearT)
                
                // Apply interpolated transforms to avatar
                for (jointName, jointIndex) in self.jointIndices {
                    guard let prevTransform = prevKeyframe.pose.transforms[jointName],
                          let nextTransform = nextKeyframe.pose.transforms[jointName] else { continue }
                    
                    let interpolatedRotation = simd_slerp(prevTransform.rotation, nextTransform.rotation, easedT)
                    
                    var newTransform = model.jointTransforms[jointIndex]
                    newTransform.rotation = interpolatedRotation
                    
                    model.jointTransforms[jointIndex] = newTransform
                }
                
                // ========== UPDATE DEVICE POSE ==========
                if let devicePose = self.interpolatePose(from: self.devicePoses, at: currentTime) {
                    self.deviceEntity?.transform = Transform(
                        scale: [1, 1, 1],
                        rotation: devicePose.q,
                        translation: devicePose.p
                    )
                }
                
                // ========== UPDATE OBJECT POSES ==========
                // Get current device pose for relative positioning
//                guard let currentDevicePose = self.interpolatePose(from: self.devicePoses, at: currentTime) else { return }
//                
//                // Group object poses by anchorID and update each
//                for (anchorID, entity) in self.objectEntities {
//                    // Filter poses for this specific object
//                    let objectPosesForAnchor = self.objectPoses.filter { $0.anchorID == anchorID }
//                    
//                    if let objectPose = self.interpolatePose(from: objectPosesForAnchor, at: currentTime) {
//                        // Position object relative to device
//                        let relativePosition = self.transformToDeviceSpace(
//                            worldPosition: objectPose.p,
//                            worldRotation: objectPose.q,
//                            devicePose: currentDevicePose
//                        )
//                        
//                        entity.transform = Transform(
//                            scale: [1, 1, 1],
//                            rotation: relativePosition.rotation,
//                            translation: relativePosition.position
//                        )
//                    }
//                }
                for (anchorID, entity) in self.objectEntities {
                    let objectPosesForAnchor = self.objectPoses.filter { $0.anchorID == anchorID }

                    if let objectPose = self.interpolatePose(from: objectPosesForAnchor, at: currentTime) {
                        entity.transform = Transform(
                            scale: [1, 1, 1],
                            rotation: objectPose.q,
                            translation: objectPose.p
                        )
                    }
                }
                
            } as! AnyCancellable
            
            print("🎬 Animation started successfully!")
            
        } catch {
            print("❌ Failed to load CSV animation: \(error)")
            print("⚠️ Falling back to hardcoded animation")
            animationKeyframes = getHardcodedKeyframes()
            await setupAnimationWithKeyframes(model: model)
        }
    }
    
    // MARK: - Pose Interpolation
    private func interpolatePose(from poses: [PoseSample], at time: TimeInterval) -> PoseSample? {
        guard !poses.isEmpty else { return nil }
        
        // Find surrounding poses
        var prevPose = poses.first!
        var nextPose = poses.first!
        
        for i in 0..<poses.count {
            if poses[i].t <= time {
                prevPose = poses[i]
            }
            if poses[i].t >= time {
                nextPose = poses[i]
                break
            }
        }
        
        // If exact match or at boundaries
        if prevPose.t == nextPose.t {
            return prevPose
        }
        
        // Linear interpolation
        let t = Float((time - prevPose.t) / (nextPose.t - prevPose.t))
        let interpPosition = prevPose.p + (nextPose.p - prevPose.p) * t
        let interpRotation = simd_slerp(prevPose.q, nextPose.q, t)
        
        return PoseSample(
            t: time,
            p: interpPosition,
            q: interpRotation,
            anchorID: prevPose.anchorID
        )
    }
    
    // MARK: - Transform to Device-Relative Space
    private func transformToDeviceSpace(
        worldPosition: SIMD3<Float>,
        worldRotation: simd_quatf,
        devicePose: PoseSample
    ) -> (position: SIMD3<Float>, rotation: simd_quatf) {
        // Transform object from world space to device-relative space
        
        // 1. Compute relative position
        let relativePosition = worldPosition - devicePose.p
        
        // 2. Rotate relative position by inverse of device rotation
        let deviceRotationInverse = simd_inverse(devicePose.q)
        let rotatedRelativePosition = deviceRotationInverse.act(relativePosition)
        
        // 3. Compute relative rotation
        let relativeRotation = deviceRotationInverse * worldRotation
        
        return (rotatedRelativePosition, relativeRotation)
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
