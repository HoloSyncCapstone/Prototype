// ImmersiveView.swift - Complete Skeleton with Hierarchy and Bone Lines
import SwiftUI
import RealityKit
import simd
import Combine

// MARK: - Main View
struct ImmersiveView: View {
    @EnvironmentObject var viewModel: ViewModel
    @State private var subscription: AnyCancellable?
    
    // Skeleton visualization
    @State private var skeletonJointSamples: [SkeletonJointSample] = []
    @State private var skeletonSpheres: [String: ModelEntity] = [:] // joint name -> sphere entity
    @State private var boneLineEntities: [String: ModelEntity] = [:] // "parent_child" -> line entity
    
    // Object & Device tracking
    @State private var devicePoses: [PoseSample] = []
    @State private var objectPoses: [PoseSample] = []
    @State private var deviceEntity: ModelEntity?
    @State private var objectEntities: [String: ModelEntity] = [:]

    // Root anchor for skeleton
    @State private var rootAnchorPosition: SIMD3<Float> = .zero
    @State private var rootAnchorRotation: simd_quatf = simd_quatf()
    
    // Timer for animation loop
    @State private var animationTimer: Timer?
    
    var body: some View {
        RealityView { content, attachments in
            do {
                // Lighting
                let lightEntity = DirectionalLight()
                lightEntity.position = SIMD3<Float>(20, 20, 20)
                lightEntity.look(at: [0, 0, 0], from: lightEntity.position, relativeTo: nil)
                lightEntity.light.intensity = 5000
                content.add(lightEntity)
                
                // Add playback controls attachment
                if let controlsEntity = attachments.entity(for: "controls") {
                    controlsEntity.position = [0.8, 1.2, -2]
                    content.add(controlsEntity)
                }
                
                // Create device cube (white)
                let headsetBox = MeshResource.generateBox(size: [0.15, 0.10, 0.12])
                var headsetMat = PhysicallyBasedMaterial()
                headsetMat.baseColor = .init(tint: .white)
                headsetMat.emissiveColor = .init(color: .white)
                headsetMat.emissiveIntensity = 1.0
                let deviceCube = ModelEntity(mesh: headsetBox, materials: [headsetMat])
                deviceCube.name = "deviceCube"
                content.add(deviceCube)
                self.deviceEntity = deviceCube
                
                // Create object entities
                let uniqueAnchorIDs = Set(PoseCSVLoader.load(resource: "object_pose_data_4").compactMap { $0.anchorID })
                print("📦 Found \(uniqueAnchorIDs.count) unique objects: \(uniqueAnchorIDs)")
                for (index, anchorID) in uniqueAnchorIDs.enumerated() {
                    let objectBox = MeshResource.generateBox(size: [0.08, 0.08, 0.08])
                    var objectMat = PhysicallyBasedMaterial()
                    
                    let colors: [UIColor] = [.red, .green, .blue, .yellow, .cyan, .magenta, .orange]
                    objectMat.baseColor = .init(tint: colors[index % colors.count])
                    objectMat.emissiveColor = .init(color: colors[index % colors.count])
                    objectMat.emissiveIntensity = 2.0
                    
                    let objectEntity = ModelEntity(mesh: objectBox, materials: [objectMat])
                    objectEntity.name = "object_\(anchorID)"
                    content.add(objectEntity)
                    
                    objectEntities[anchorID] = objectEntity
                }
                
                // Create skeleton visualization (joints + bones)
                createSkeletonVisualization(content: content)
                
                // Setup animation from CSV
                Task {
                    try await Task.sleep(nanoseconds: 100_000_000)
                    await setupAnimationFromCSV()
                }
                
            } catch {
                print("Failed to setup scene: \(error)")
            }
        } attachments: {
            Attachment(id: "controls") {
                PlaybackControlsView()
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
    
    // MARK: - Create Skeleton Visualization
    private func createSkeletonVisualization(content: RealityViewContent) {
        // Create joint spheres
        for (jointName, _) in SkeletonHierarchy.hierarchy {
            var material = PhysicallyBasedMaterial()
            var radius: Float = 0.008
            
            // Color coding and sizing based on joint type
            if jointName == "head" {
                material.baseColor = .init(tint: .systemYellow)
                material.emissiveColor = .init(color: .yellow)
                material.emissiveIntensity = 3.0
                radius = 0.020
            } else if jointName == SkeletonHierarchy.rootJoint {
                // Root joint - make it very visible
                material.baseColor = .init(tint: .systemRed)
                material.emissiveColor = .init(color: .red)
                material.emissiveIntensity = 4.0
                radius = 0.025
            } else if jointName.contains("spine") {
                material.baseColor = .init(tint: .systemPurple)
                material.emissiveColor = .init(color: .purple)
                material.emissiveIntensity = 2.0
                radius = 0.012
            } else if jointName.contains("shoulder") {
                material.baseColor = .init(tint: .systemOrange)
                material.emissiveColor = .init(color: .orange)
                material.emissiveIntensity = 2.5
                radius = 0.015
            } else if jointName.contains("elbow") || jointName.contains("wrist") {
                material.baseColor = .init(tint: .systemCyan)
                material.emissiveIntensity = 1.5
                radius = 0.010
            } else if jointName.contains("right_") {
                // Right hand joints - blue
                material.baseColor = .init(tint: .systemBlue)
                material.emissiveIntensity = 1.0
                radius = 0.006
                
                if jointName.contains("Knuckle") {
                    radius = 0.008
                    material.emissiveIntensity = 1.5
                } else if jointName.contains("Tip") {
                    material.emissiveIntensity = 2.0
                }
            } else if jointName.contains("left_") {
                // Left hand joints - green
                material.baseColor = .init(tint: .systemGreen)
                material.emissiveIntensity = 1.0
                radius = 0.006
                
                if jointName.contains("Knuckle") {
                    radius = 0.008
                    material.emissiveIntensity = 1.5
                } else if jointName.contains("Tip") {
                    material.emissiveIntensity = 2.0
                }
            }
            
            let sphere = MeshResource.generateSphere(radius: radius)
            let sphereEntity = ModelEntity(mesh: sphere, materials: [material])
            sphereEntity.name = "joint_\(jointName)"
            content.add(sphereEntity)
            skeletonSpheres[jointName] = sphereEntity
        }
        
        print("✅ Created \(skeletonSpheres.count) skeleton joint spheres")
        
        // Create bone lines
        let boneConnections = SkeletonHierarchy.getBoneConnections()
        for (parent, child) in boneConnections {
            let boneLine = createBoneLine()
            boneLine.name = "bone_\(parent)_\(child)"
            content.add(boneLine)
            boneLineEntities["\(parent)_\(child)"] = boneLine
        }
        
        print("✅ Created \(boneLineEntities.count) bone lines")
    }
    
    // MARK: - Create Bone Line
    private func createBoneLine() -> ModelEntity {
        // Create a thin cylinder to represent a bone
        let cylinder = MeshResource.generateBox(size: [0.003, 1.0, 0.003])
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .white.withAlphaComponent(0.7))
        material.emissiveColor = .init(color: .white)
        material.emissiveIntensity = 0.5
        
        let lineEntity = ModelEntity(mesh: cylinder, materials: [material])
        return lineEntity
    }
    
    // MARK: - Update Bone Line
    private func updateBoneLine(from parentPos: SIMD3<Float>, to childPos: SIMD3<Float>, entity: ModelEntity) {
        let direction = childPos - parentPos
        let distance = simd_length(direction)
        
        guard distance > 0.001 else {
            entity.isEnabled = false
            return
        }
        
        entity.isEnabled = true
        
        // Position at midpoint
        let midpoint = (parentPos + childPos) / 2.0
        entity.position = midpoint
        
        // Scale to match distance
        entity.scale = [1.0, distance, 1.0]
        
        // Rotate to align with direction
        let up = SIMD3<Float>(0, 1, 0)
        let normalizedDir = simd_normalize(direction)
        
        // Calculate rotation quaternion
        let dot = simd_dot(up, normalizedDir)
        if abs(dot - 1.0) < 0.001 {
            // Already aligned
            entity.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
        } else if abs(dot + 1.0) < 0.001 {
            // Opposite direction
            entity.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        } else {
            let axis = simd_normalize(simd_cross(up, normalizedDir))
            let angle = acos(dot)
            entity.orientation = simd_quatf(angle: angle, axis: axis)
        }
    }
    
    @MainActor
    private func setupAnimationFromCSV() async {
        do {
            print("📦 Loading datasets...")
            
            devicePoses = PoseCSVLoader.load(resource: "device_pose_data_3")
            print("✅ Loaded \(devicePoses.count) device poses")
            
            objectPoses = PoseCSVLoader.load(resource: "object_pose_data_4")
            print("✅ Loaded \(objectPoses.count) object poses")
            
            // Load complete skeleton data
            skeletonJointSamples = SkeletonCSVLoader.load(resource: "complete_skeleton_data")
            print("✅ Loaded \(skeletonJointSamples.count) complete skeleton samples")
            
            // === ESTABLISH ROOT ANCHOR ===
            // Use the first root joint position as the local anchor
            if let firstSample = skeletonJointSamples.first,
               let rootPos = firstSample.joints[SkeletonHierarchy.rootJoint] {
                rootAnchorPosition = rootPos
                // For now, no rotation offset (identity quaternion)
                rootAnchorRotation = simd_quatf()
                print("🌍 Root anchor set at \(SkeletonHierarchy.rootJoint): \(rootAnchorPosition)")
                
                // Transform all skeleton data to be relative to root
                normalizeSkeletonToRoot()
            }
            
            // Set total time
            let skeletonTime = skeletonJointSamples.last?.timestamp ?? 0
            viewModel.totalTime = skeletonTime
            print("⏱️ Total animation time: \(viewModel.totalTime) seconds")
            
            // Start animation loop
            startAnimationLoop()
            
            print("🎬 Animation started successfully!")
            
        } catch {
            print("❌ Failed to load CSV animation: \(error)")
        }
    }
    
    // MARK: - Normalize Skeleton to Root
    private func normalizeSkeletonToRoot() {
        // Transform all joint positions to be relative to the root joint
        skeletonJointSamples = skeletonJointSamples.map { sample in
            var normalizedJoints: [String: SIMD3<Float>] = [:]
            
            // Get the root position for this frame
            guard let rootPos = sample.joints[SkeletonHierarchy.rootJoint] else {
                return sample
            }
            
            // Make all joints relative to root
            for (jointName, worldPos) in sample.joints {
                normalizedJoints[jointName] = worldPos - rootPos
            }
            
            return SkeletonJointSample(
                frame: sample.frame,
                timestamp: sample.timestamp,
                joints: normalizedJoints,
                rotations: sample.rotations
            )
        }
        
        print("✅ Normalized \(skeletonJointSamples.count) samples to root anchor")
    }
    
    // MARK: - Start Animation Loop
    private func startAnimationLoop() {
        animationTimer?.invalidate()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            Task { @MainActor in
                if !self.viewModel.isPlaying {
                    return
                }
                
                self.viewModel.updateTime(1.0/60.0)
                let currentTime = self.viewModel.currentTime
                
                // Update device
                if let devicePose = self.interpolatePose(from: self.devicePoses, at: currentTime) {
                    self.deviceEntity?.transform = Transform(
                        scale: [1, 1, 1],
                        rotation: devicePose.q,
                        translation: devicePose.p
                    )
                }
                
                // Update objects
                for (anchorID, entity) in self.objectEntities {
                    let objectPosesForAnchor = self.objectPoses.filter { $0.anchorID == anchorID }
                    
                    if let objectPose = self.interpolatePose(from: objectPosesForAnchor, at: currentTime) {
                        entity.position = objectPose.p
                        entity.orientation = objectPose.q
                    }
                }
                
                // Update skeleton joints and bones
                if let skeletonSample = self.interpolateSkeletonJoints(at: currentTime) {
                    // Update joint positions (these are already relative to root)
                    for (jointName, relativePos) in skeletonSample.joints {
                        if let sphere = self.skeletonSpheres[jointName] {
                            // Position is already relative to root anchor
                            sphere.position = relativePos
                        }
                    }
                    
                    // Update bone lines
                    let boneConnections = SkeletonHierarchy.getBoneConnections()
                    for (parent, child) in boneConnections {
                        if let parentPos = skeletonSample.joints[parent],
                           let childPos = skeletonSample.joints[child],
                           let boneLine = self.boneLineEntities["\(parent)_\(child)"] {
                            self.updateBoneLine(from: parentPos, to: childPos, entity: boneLine)
                        }
                    }
                    
                    // Debug log once per second
                    if Int(currentTime * 60) % 60 == 0 {
                        if let rootPos = skeletonSample.joints[SkeletonHierarchy.rootJoint] {
                            print("🦴 t=\(String(format: "%.2f", currentTime)) | Root: \(rootPos) | Joints: \(skeletonSample.joints.count)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Interpolate Skeleton Joints
    private func interpolateSkeletonJoints(at time: TimeInterval) -> SkeletonJointSample? {
        guard !skeletonJointSamples.isEmpty else { return nil }
        
        var prevSample = skeletonJointSamples.first!
        var nextSample = skeletonJointSamples.first!
        
        for i in 0..<skeletonJointSamples.count {
            if skeletonJointSamples[i].timestamp <= time {
                prevSample = skeletonJointSamples[i]
            }
            if skeletonJointSamples[i].timestamp >= time {
                nextSample = skeletonJointSamples[i]
                break
            }
        }
        
        if prevSample.timestamp == nextSample.timestamp {
            return prevSample
        }
        
        let t = Float((time - prevSample.timestamp) / (nextSample.timestamp - prevSample.timestamp))
        var interpolatedJoints: [String: SIMD3<Float>] = [:]
        var interpolatedRotations: [String: simd_quatf] = [:]
        
        for (jointName, prevPos) in prevSample.joints {
            if let nextPos = nextSample.joints[jointName] {
                interpolatedJoints[jointName] = prevPos + (nextPos - prevPos) * t
            }
        }
        
        for (jointName, prevRot) in prevSample.rotations {
            if let nextRot = nextSample.rotations[jointName] {
                interpolatedRotations[jointName] = simd_slerp(prevRot, nextRot, t)
            }
        }
        
        return SkeletonJointSample(
            frame: prevSample.frame,
            timestamp: time,
            joints: interpolatedJoints,
            rotations: interpolatedRotations
        )
    }
    
    // MARK: - Pose Interpolation
    private func interpolatePose(from poses: [PoseSample], at time: TimeInterval) -> PoseSample? {
        guard !poses.isEmpty else { return nil }
        
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
        
        if prevPose.t == nextPose.t {
            return prevPose
        }
        
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
}
