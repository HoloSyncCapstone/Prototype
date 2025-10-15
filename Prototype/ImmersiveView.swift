// ImmersiveView.swift - Joint Point Cloud Visualization
import SwiftUI
import RealityKit
import simd
import Combine

// MARK: - Data Structures
struct HandJointSample {
    let t: Double
    let chirality: String // "left" or "right"
    let joints: [String: SIMD3<Float>] // joint name -> position
}

// MARK: - Main View
struct ImmersiveView: View {
    @EnvironmentObject var viewModel: ViewModel
    @State private var subscription: AnyCancellable?
    
    // Joint visualization
    @State private var handJointSamples: [HandJointSample] = []
    @State private var jointSpheres: [String: ModelEntity] = [:] // joint name -> sphere entity
    
    // Object & Device tracking
    @State private var devicePoses: [PoseSample] = []
    @State private var objectPoses: [PoseSample] = []
    @State private var deviceEntity: ModelEntity?
    @State private var objectEntities: [String: ModelEntity] = [:]

    @State private var globalAnchorRotation: simd_quatf = simd_quatf()
    @State private var globalAnchorPosition: SIMD3<Float> = .zero
    
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
                
                // Create device cube (white) - make it bigger and visible
                let headsetBox = MeshResource.generateBox(size: [0.15, 0.10, 0.12])
                var headsetMat = PhysicallyBasedMaterial()
                headsetMat.baseColor = .init(tint: .white)
                headsetMat.emissiveColor = .init(color: .white)
                headsetMat.emissiveIntensity = 1.0
                let deviceCube = ModelEntity(mesh: headsetBox, materials: [headsetMat])
                deviceCube.name = "deviceCube"
                content.add(deviceCube)
                self.deviceEntity = deviceCube
                
                // Create object entities - make them bigger and glowing
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
                
                // Create joint visualization spheres
                createJointSpheres(content: content)
                
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
            // Clean up timer when view disappears
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }
    
    // MARK: - Create Joint Spheres
    private func createJointSpheres(content: RealityViewContent) {
        // Define all hand joints we want to visualize
        let jointNames = [
            // Right hand
            "right_wrist", "right_thumb_tip", "right_index_tip", "right_middle_tip",
            "right_ring_tip", "right_pinky_tip",
            "right_thumb_knuckle", "right_index_knuckle", "right_middle_knuckle",
            "right_ring_knuckle", "right_pinky_knuckle",
            // Left hand
            "left_wrist", "left_thumb_tip", "left_index_tip", "left_middle_tip",
            "left_ring_tip", "left_pinky_tip",
            "left_thumb_knuckle", "left_index_knuckle", "left_middle_knuckle",
            "left_ring_knuckle", "left_pinky_knuckle"
        ]
        
        for jointName in jointNames {
            let sphere = MeshResource.generateSphere(radius: 0.01)
            var material = PhysicallyBasedMaterial()
            
            // Color code: right hand = blue, left hand = green
            if jointName.contains("right") {
                material.baseColor = .init(tint: .systemBlue)
            } else {
                material.baseColor = .init(tint: .systemGreen)
            }
            
            // Wrists and tips are brighter and larger
            if jointName.contains("wrist") {
                material.emissiveColor = .init(color: jointName.contains("right") ? .blue : .green)
                material.emissiveIntensity = 3.0
                let largeSphere = MeshResource.generateSphere(radius: 0.015) // Larger wrist
                let sphereEntity = ModelEntity(mesh: largeSphere, materials: [material])
                sphereEntity.name = jointName
                content.add(sphereEntity)
                jointSpheres[jointName] = sphereEntity
            } else if jointName.contains("tip") {
                material.emissiveIntensity = 2.0
                let sphereEntity = ModelEntity(mesh: sphere, materials: [material])
                sphereEntity.name = jointName
                content.add(sphereEntity)
                jointSpheres[jointName] = sphereEntity
            } else {
                let sphereEntity = ModelEntity(mesh: sphere, materials: [material])
                sphereEntity.name = jointName
                content.add(sphereEntity)
                jointSpheres[jointName] = sphereEntity
            }
        }
        
        print("✅ Created \(jointSpheres.count) joint visualization spheres")
    }
    
    @MainActor
    private func setupAnimationFromCSV() async {
        do {
            // Load all three datasets
            print("📦 Loading datasets...")
            
            devicePoses = PoseCSVLoader.load(resource: "device_pose_data_3")
            print("✅ Loaded \(devicePoses.count) device poses")
            
            objectPoses = PoseCSVLoader.load(resource: "object_pose_data_4")
            print("✅ Loaded \(objectPoses.count) object poses")
            
            handJointSamples = try await loadHandJointData(from: "hand_data_pivoted")
            print("✅ Loaded \(handJointSamples.count) hand joint samples")
            
            // === ESTABLISH GLOBAL ANCHOR ===
            if let firstDevicePose = devicePoses.first {
                globalAnchorPosition = firstDevicePose.p
                globalAnchorRotation = firstDevicePose.q
                print("🌍 Global anchor set at position: \(globalAnchorPosition)")
                
                // Normalize all poses relative to this anchor
                normalizeAllPosesToGlobalAnchor()
            }
            
            // Set total time
            if let lastSample = handJointSamples.last {
                viewModel.totalTime = lastSample.t
                print("⏱️ Total animation time: \(lastSample.t) seconds")
            }
            
            // Start animation loop
            startAnimationLoop()
            
            print("🎬 Animation started successfully!")
            
        } catch {
            print("❌ Failed to load CSV animation: \(error)")
        }
    }
    
    // MARK: - Load Hand Joint Data
    private func loadHandJointData(from filename: String) async throws -> [HandJointSample] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "csv"),
              let csvData = try? String(contentsOf: url, encoding: .utf8) else {
            throw NSError(domain: "CSV", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        
        let rows = csvData.components(separatedBy: .newlines).map { $0.components(separatedBy: ",") }
        guard rows.count > 1 else { throw NSError(domain: "CSV", code: 400, userInfo: nil) }
        
        let headers = rows[0].map { $0.trimmingCharacters(in: .whitespaces) }
        var samples: [HandJointSample] = []
        
        let samplingRate = 2  // Reduced from 5 to 2 for smoother/faster animation
        
        for (index, row) in rows.dropFirst().enumerated() {
            guard index % samplingRate == 0, row.count > 2 else { continue }
            
            var rowData: [String: String] = [:]
            for (i, header) in headers.enumerated() {
                if i < row.count {
                    rowData[header] = row[i]
                }
            }
            
            guard let timeString = rowData["t_mono"],
                  let time = Double(timeString),
                  let chirality = rowData["chirality"]?.trimmingCharacters(in: .whitespaces).lowercased() else {
                continue
            }
            
            // Extract joint positions
            var joints: [String: SIMD3<Float>] = [:]
            
            // Key joints to extract
            let jointPrefixes = ["forearmWrist", "thumbTip", "indexFingerTip", "middleFingerTip",
                                "ringFingerTip", "littleFingerTip",
                                "thumbKnuckle", "indexFingerKnuckle", "middleFingerKnuckle",
                                "ringFingerKnuckle", "littleFingerKnuckle"]
            
            for prefix in jointPrefixes {
                if let px = Float(rowData["\(prefix)_px"] ?? ""),
                   let py = Float(rowData["\(prefix)_py"] ?? ""),
                   let pz = Float(rowData["\(prefix)_pz"] ?? "") {
                    let position = SIMD3<Float>(px, py, pz)
                    
                    // Map to our sphere names
                    var simpleName = prefix
                        .replacingOccurrences(of: "forearmWrist", with: "wrist")
                        .replacingOccurrences(of: "Finger", with: "")
                        .replacingOccurrences(of: "Tip", with: "_tip")
                        .replacingOccurrences(of: "Knuckle", with: "_knuckle")
                        .replacingOccurrences(of: "little", with: "pinky")
                        .lowercased()
                    
                    joints["\(chirality)_\(simpleName)"] = position
                }
            }
            
            samples.append(HandJointSample(t: time, chirality: chirality, joints: joints))
        }
        
        // Normalize times
        if let firstTime = samples.first?.t {
            samples = samples.map {
                HandJointSample(t: $0.t - firstTime, chirality: $0.chirality, joints: $0.joints)
            }
        }
        
        return samples
    }
    
    // MARK: - Start Animation Loop
    private func startAnimationLoop() {
        // Invalidate any existing timer first
        animationTimer?.invalidate()
        
        // Create and store the new timer
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
                    
                    // Debug log every 60 frames (once per second)
                    if Int(currentTime * 60) % 60 == 0 {
                        print("🎯 t=\(String(format: "%.2f", currentTime)) | Device: \(devicePose.p)")
                    }
                }
                
                // Update objects - use absolute positions (already normalized)
                for (anchorID, entity) in self.objectEntities {
                    let objectPosesForAnchor = self.objectPoses.filter { $0.anchorID == anchorID }
                    
                    if let objectPose = self.interpolatePose(from: objectPosesForAnchor, at: currentTime) {
                        // Objects are already normalized to global anchor, use directly
                        entity.position = objectPose.p
                        entity.orientation = objectPose.q
                        
                        // Debug log once per second
                        if Int(currentTime * 60) % 60 == 0 {
                            print("📦 Object: \(objectPose.p)")
                        }
                    }
                }
                
                // Update hand joints - Try using RAW positions without normalization
                if let jointSample = self.interpolateHandJoints(at: currentTime) {
                    for (jointName, position) in jointSample.joints {
                        if let sphere = self.jointSpheres[jointName] {
                            // OPTION 1: Use raw position (no normalization)
                            sphere.position = position
                            
                            // Debug log wrist positions once per second
                            if jointName.contains("wrist") && Int(currentTime * 60) % 60 == 0 {
                                print("✋ \(jointName) RAW: \(position)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Interpolate Hand Joints
    private func interpolateHandJoints(at time: TimeInterval) -> HandJointSample? {
        guard !handJointSamples.isEmpty else { return nil }
        
        var prevSample = handJointSamples.first!
        var nextSample = handJointSamples.first!
        
        for i in 0..<handJointSamples.count {
            if handJointSamples[i].t <= time {
                prevSample = handJointSamples[i]
            }
            if handJointSamples[i].t >= time {
                nextSample = handJointSamples[i]
                break
            }
        }
        
        if prevSample.t == nextSample.t {
            return prevSample
        }
        
        let t = Float((time - prevSample.t) / (nextSample.t - prevSample.t))
        var interpolatedJoints: [String: SIMD3<Float>] = [:]
        
        for (jointName, prevPos) in prevSample.joints {
            if let nextPos = nextSample.joints[jointName] {
                interpolatedJoints[jointName] = prevPos + (nextPos - prevPos) * t
            }
        }
        
        return HandJointSample(t: time, chirality: prevSample.chirality, joints: interpolatedJoints)
    }
    
    // MARK: - Global Anchor Normalization
    private func normalizeAllPosesToGlobalAnchor() {
        let anchorInverse = simd_inverse(globalAnchorRotation)
        
        // Normalize device poses
        devicePoses = devicePoses.map { pose in
            let relativePos = anchorInverse.act(pose.p - globalAnchorPosition)
            let relativeRot = anchorInverse * pose.q
            return PoseSample(t: pose.t, p: relativePos, q: relativeRot, anchorID: pose.anchorID)
        }
        
        // Normalize object poses
        objectPoses = objectPoses.map { pose in
            let relativePos = anchorInverse.act(pose.p - globalAnchorPosition)
            let relativeRot = anchorInverse * pose.q
            return PoseSample(t: pose.t, p: relativePos, q: relativeRot, anchorID: pose.anchorID)
        }
        
        print("✅ All poses normalized to global anchor")
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
