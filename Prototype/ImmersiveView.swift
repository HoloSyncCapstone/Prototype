// ImmersiveView.swift - Skeleton + Hand Joints Visualization
import SwiftUI
import RealityKit
import simd
import Combine

struct ImmersiveView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    // Animation data
    @State private var skeletonFrames: [ImprovedSkeletonFrame] = []
    @State private var devicePoses: [PoseSample] = []
    @State private var handSamples: [HandSample] = []
    
    // Visual entities - Skeleton
    @State private var jointSpheres: [String: ModelEntity] = [:]
    @State private var boneLines: [String: ModelEntity] = [:]
    @State private var rootMarker: ModelEntity?
    @State private var deviceCube: ModelEntity?
    
    // Visual entities - Hands
    @State private var handJointSpheres: [String: ModelEntity] = [:]
    @State private var fingerLines: [String: ModelEntity] = [:]
    
    // Animation timer
    @State private var animationTimer: Timer?
    
    var body: some View {
        RealityView { content, attachments in
            setupScene(content: content)
            
            // Add playback controls
            if let controls = attachments.entity(for: "controls") {
                controls.position = [0, 1.5, -1.5]
                content.add(controls)
            }
            
            Task {
                await loadDataAndSolveIK()
                startAnimation()
            }
            
        } attachments: {
            Attachment(id: "controls") {
                PlaybackControlsView()
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
    }
    
    // MARK: - Scene Setup
    private func setupScene(content: RealityViewContent) {
        // Add lighting
        let light = DirectionalLight()
        light.position = [5, 5, 5]
        light.look(at: [0, 0, 0], from: light.position, relativeTo: nil)
        light.light.intensity = 3000
        content.add(light)
        
        // Create device cube (head tracker)
        let cube = MeshResource.generateBox(size: [0.12, 0.08, 0.10])
        var cubeMat = PhysicallyBasedMaterial()
        cubeMat.baseColor = .init(tint: .white)
        cubeMat.emissiveColor = .init(color: .white)
        cubeMat.emissiveIntensity = 2.0
        let cubeEntity = ModelEntity(mesh: cube, materials: [cubeMat])
        content.add(cubeEntity)
        deviceCube = cubeEntity
        
        // Create root marker (lower spine - our anchor point)
        let rootSphere = MeshResource.generateSphere(radius: 0.025)
        var rootMat = PhysicallyBasedMaterial()
        rootMat.baseColor = .init(tint: .red)
        rootMat.emissiveColor = .init(color: .red)
        rootMat.emissiveIntensity = 5.0
        let root = ModelEntity(mesh: rootSphere, materials: [rootMat])
        content.add(root)
        rootMarker = root
        
        // Create skeleton joint spheres
        createJointSpheres(content: content)
        
        // Create skeleton bone lines
        createBoneLines(content: content)
        
        // Create hand joint spheres
        createHandJointSpheres(content: content)
        
        // Create finger bone lines
        createFingerLines(content: content)
    }
    
    // MARK: - Create Joint Spheres (Skeleton)
    private func createJointSpheres(content: RealityViewContent) {
        let jointNames = [
            "head", "neck", "upper_spine", "shoulder_anchor", "lower_spine",
            "left_shoulder", "right_shoulder",
            "left_elbow", "right_elbow",
            "left_wrist", "right_wrist"
        ]
        
        for jointName in jointNames {
            var radius: Float = 0.015
            var color: UIColor = .systemBlue
            var emissiveIntensity: Float = 2.0
            
            // Customize by joint type
            if jointName == "head" {
                radius = 0.03
                color = .systemYellow
                emissiveIntensity = 3.0
            } else if jointName == "lower_spine" {
                radius = 0.025
                color = .systemRed
                emissiveIntensity = 4.0
            } else if jointName == "shoulder_anchor" {
                // NEW: Static shoulder anchor point
                radius = 0.022
                color = .systemPink
                emissiveIntensity = 4.5
            } else if jointName.contains("shoulder") {
                radius = 0.02
                color = .systemOrange
                emissiveIntensity = 2.5
            } else if jointName.contains("elbow") {
                radius = 0.018
                color = .systemCyan
            } else if jointName.contains("wrist") {
                radius = 0.016
                color = .systemGreen
            } else if jointName.contains("spine") {
                radius = 0.018
                color = .systemPurple
            }
            
            let sphere = MeshResource.generateSphere(radius: radius)
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: color)
            material.emissiveColor = .init(color: color)
            material.emissiveIntensity = emissiveIntensity
            
            let entity = ModelEntity(mesh: sphere, materials: [material])
            entity.name = jointName
            content.add(entity)
            jointSpheres[jointName] = entity
        }
        
        print("✅ Created \(jointSpheres.count) skeleton joint spheres (including shoulder anchor)")
    }
    
    // MARK: - Create Hand Joint Spheres
    private func createHandJointSpheres(content: RealityViewContent) {
        // Define all hand joints we want to visualize
        let fingers = ["thumb", "index", "middle", "ring", "little"]
        let jointTypes = ["Knuckle", "IntermediateBase", "IntermediateTip", "Tip"]
        let hands = ["left", "right"]
        
        for hand in hands {
            let baseColor: UIColor = hand == "left" ? .systemGreen : .systemBlue
            
            for finger in fingers {
                for jointType in jointTypes {
                    let jointName = "\(hand)_\(finger)\(jointType)"
                    
                    // Size based on joint type
                    var radius: Float = 0.008
                    var intensity: Float = 1.5
                    
                    if jointType == "Tip" {
                        radius = 0.010  // Fingertips slightly larger
                        intensity = 2.5
                    } else if jointType == "Knuckle" {
                        radius = 0.009
                        intensity = 2.0
                    }
                    
                    let sphere = MeshResource.generateSphere(radius: radius)
                    var material = PhysicallyBasedMaterial()
                    material.baseColor = .init(tint: baseColor)
                    material.emissiveColor = .init(color: baseColor)
                    material.emissiveIntensity = intensity
                    
                    let entity = ModelEntity(mesh: sphere, materials: [material])
                    entity.name = jointName
                    content.add(entity)
                    handJointSpheres[jointName] = entity
                }
            }
        }
        
        print("✅ Created \(handJointSpheres.count) hand joint spheres")
    }
    
    // MARK: - Create Bone Lines (Skeleton)
    private func createBoneLines(content: RealityViewContent) {
        for (start, end) in ImprovedSkeletonFrame.boneConnections {
            let boneName = "\(start)_to_\(end)"
            
            // Create thin cylinder for each bone
            let cylinder = MeshResource.generateCylinder(height: 0.1, radius: 0.004)
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: .gray)
            material.emissiveColor = .init(color: .gray)
            material.emissiveIntensity = 1.0
            
            let lineEntity = ModelEntity(mesh: cylinder, materials: [material])
            lineEntity.name = boneName
            content.add(lineEntity)
            boneLines[boneName] = lineEntity
        }
        
        print("✅ Created \(boneLines.count) skeleton bone lines")
    }
    
    // MARK: - Create Finger Lines
    private func createFingerLines(content: RealityViewContent) {
        let fingers = ["thumb", "index", "middle", "ring", "little"]
        let hands = ["left", "right"]
        
        // Connections for each finger
        let fingerConnections = [
            ("Knuckle", "IntermediateBase"),
            ("IntermediateBase", "IntermediateTip"),
            ("IntermediateTip", "Tip")
        ]
        
        for hand in hands {
            let color: UIColor = hand == "left" ? .systemGreen : .systemBlue
            
            for finger in fingers {
                for (start, end) in fingerConnections {
                    let lineName = "\(hand)_\(finger)\(start)_to_\(finger)\(end)"
                    
                    let cylinder = MeshResource.generateCylinder(height: 0.02, radius: 0.002)
                    var material = PhysicallyBasedMaterial()
                    material.baseColor = .init(tint: color)
                    material.emissiveColor = .init(color: color)
                    material.emissiveIntensity = 0.8
                    
                    let lineEntity = ModelEntity(mesh: cylinder, materials: [material])
                    lineEntity.name = lineName
                    content.add(lineEntity)
                    fingerLines[lineName] = lineEntity
                }
            }
        }
        
        print("✅ Created \(fingerLines.count) finger bone lines")
    }
    
    // MARK: - Load Data and Solve IK
    @MainActor
    private func loadDataAndSolveIK() async {
        print("📦 Loading data...")
        
        // Load device poses (head tracking)
        devicePoses = PoseCSVLoader.load(resource: "device_pose_data_4")
        print("✅ Loaded \(devicePoses.count) device poses")
        
        // Load hand data
        handSamples = await loadHandData()
        print("✅ Loaded \(handSamples.count) hand samples")
        
        // Solve IK for entire timeline
        print("🤖 Solving IK...")
        skeletonFrames = ImprovedAnimationBuilder.buildTimeline(
            devicePoses: devicePoses,
            handSamples: handSamples
        )
        
        // Set animation duration
        if let lastFrame = skeletonFrames.last {
            viewModel.totalTime = lastFrame.timestamp
        }
        
        print("⏱️ Animation duration: \(viewModel.totalTime)s")
        print("🎬 Ready to play!")
    }
    
    // MARK: - Load Hand Data from CSV
    private func loadHandData() async -> [HandSample] {
        guard let url = Bundle.main.url(forResource: "hand_data_pivoted", withExtension: "csv"),
              let csvText = try? String(contentsOf: url) else {
            print("❌ Could not load hand data")
            return []
        }
        
        let lines = csvText.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }
        
        let headers = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var samples: [HandSample] = []
        
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            
            let values = line.components(separatedBy: ",")
            guard values.count >= 3 else { continue }
            
            var data: [String: String] = [:]
            for (i, header) in headers.enumerated() {
                if i < values.count {
                    data[header] = values[i]
                }
            }
            
            guard let timeStr = data["t_mono"],
                  let time = Double(timeStr),
                  let chirality = data["chirality"]?.trimmingCharacters(in: .whitespaces).lowercased() else {
                continue
            }
            
            // Extract wrist position
            guard let wx = Float(data["forearmWrist_px"] ?? ""),
                  let wy = Float(data["forearmWrist_py"] ?? ""),
                  let wz = Float(data["forearmWrist_pz"] ?? "") else {
                continue
            }
            let wristPos = SIMD3<Float>(wx, wy, wz)
            
            // Extract all finger joints
            var joints: [String: SIMD3<Float>] = [:]
            
            let fingerJoints = [
                "thumbKnuckle", "thumbIntermediateBase", "thumbIntermediateTip", "thumbTip",
                "indexFingerKnuckle", "indexFingerIntermediateBase", "indexFingerIntermediateTip", "indexFingerTip",
                "middleFingerKnuckle", "middleFingerIntermediateBase", "middleFingerIntermediateTip", "middleFingerTip",
                "ringFingerKnuckle", "ringFingerIntermediateBase", "ringFingerIntermediateTip", "ringFingerTip",
                "littleFingerKnuckle", "littleFingerIntermediateBase", "littleFingerIntermediateTip", "littleFingerTip"
            ]
            
            for jointPrefix in fingerJoints {
                if let px = Float(data["\(jointPrefix)_px"] ?? ""),
                   let py = Float(data["\(jointPrefix)_py"] ?? ""),
                   let pz = Float(data["\(jointPrefix)_pz"] ?? "") {
                    
                    // Simplify names: indexFingerKnuckle -> indexKnuckle
                    let simpleName = jointPrefix
                        .replacingOccurrences(of: "Finger", with: "")
                        .replacingOccurrences(of: "little", with: "little")  // Keep as is
                    
                    joints[simpleName] = SIMD3<Float>(px, py, pz)
                }
            }
            
            samples.append(HandSample(
                timestamp: time,
                chirality: chirality,
                wristPosition: wristPos,
                joints: joints
            ))
        }
        
        // Normalize timestamps to start at 0
        if let firstTime = samples.first?.timestamp {
            samples = samples.map {
                HandSample(
                    timestamp: $0.timestamp - firstTime,
                    chirality: $0.chirality,
                    wristPosition: $0.wristPosition,
                    joints: $0.joints
                )
            }
        }
        
        return samples
    }
    
    // MARK: - Start Animation
    private func startAnimation() {
        animationTimer?.invalidate()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            Task { @MainActor in
                guard viewModel.isPlaying else { return }
                
                viewModel.updateTime(1.0/60.0)
                let currentTime = viewModel.currentTime
                
                // Update device cube (head)
                if let devicePose = interpolatePose(at: currentTime) {
                    deviceCube?.position = devicePose.p
                    deviceCube?.orientation = devicePose.q
                }
                
                // Update skeleton
                if let frame = interpolateSkeletonFrame(at: currentTime) {
                    updateSkeleton(frame: frame)
                }
                
                // Update hand joints
                updateHandJoints(at: currentTime)
            }
        }
    }
    
    // MARK: - Update Skeleton Visualization
    private func updateSkeleton(frame: ImprovedSkeletonFrame) {
        // Update root marker
        rootMarker?.position = frame.rootPosition
        
        // Update all joint positions
        for (jointName, position) in frame.allJoints {
            jointSpheres[jointName]?.position = position
        }
        
        // Update bone lines
        for (start, end) in ImprovedSkeletonFrame.boneConnections {
            guard let startPos = frame.allJoints[start],
                  let endPos = frame.allJoints[end],
                  let lineEntity = boneLines["\(start)_to_\(end)"] else {
                continue
            }
            
            updateBoneLine(lineEntity, from: startPos, to: endPos)
        }
    }
    
    // MARK: - Update Hand Joints
    private func updateHandJoints(at time: TimeInterval) {
        // Get left and right hand data at this time
        let leftHand = findClosestHandSample(at: time, chirality: "left")
        let rightHand = findClosestHandSample(at: time, chirality: "right")
        
        // Update left hand joints
        if let left = leftHand {
            for (jointName, position) in left.joints {
                let fullName = "left_\(jointName)"
                handJointSpheres[fullName]?.position = position
            }
            
            // Update left hand finger lines
            updateFingerLines(hand: "left", joints: left.joints)
        }
        
        // Update right hand joints
        if let right = rightHand {
            for (jointName, position) in right.joints {
                let fullName = "right_\(jointName)"
                handJointSpheres[fullName]?.position = position
            }
            
            // Update right hand finger lines
            updateFingerLines(hand: "right", joints: right.joints)
        }
    }
    
    // MARK: - Update Finger Lines
    private func updateFingerLines(hand: String, joints: [String: SIMD3<Float>]) {
        let fingers = ["thumb", "index", "middle", "ring", "little"]
        let fingerConnections = [
            ("Knuckle", "IntermediateBase"),
            ("IntermediateBase", "IntermediateTip"),
            ("IntermediateTip", "Tip")
        ]
        
        for finger in fingers {
            for (start, end) in fingerConnections {
                let startJoint = "\(finger)\(start)"
                let endJoint = "\(finger)\(end)"
                let lineName = "\(hand)_\(finger)\(start)_to_\(finger)\(end)"
                
                if let startPos = joints[startJoint],
                   let endPos = joints[endJoint],
                   let lineEntity = fingerLines[lineName] {
                    updateBoneLine(lineEntity, from: startPos, to: endPos)
                }
            }
        }
    }
    
    // MARK: - Update Bone Line Geometry
    private func updateBoneLine(_ line: ModelEntity, from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let direction = end - start
        let length = simd_length(direction)
        let midpoint = start + direction * 0.5
        
        // Position at midpoint
        line.position = midpoint
        
        // Scale to match bone length (account for default cylinder height)
        let defaultHeight: Float = line.name.contains("finger") == true ? 0.02 : 0.1
        line.scale = SIMD3<Float>(1, length / defaultHeight, 1)
        
        // Rotate to align with bone direction
        if length > 0.001 {
            let up = SIMD3<Float>(0, 1, 0)
            let normalizedDir = direction / length
            let rotationAxis = simd_cross(up, normalizedDir)
            let rotationAngle = acos(simd_dot(up, normalizedDir))
            
            if simd_length(rotationAxis) > 0.001 {
                line.orientation = simd_quatf(angle: rotationAngle, axis: simd_normalize(rotationAxis))
            }
        }
    }
    
    // MARK: - Find Closest Hand Sample
    private func findClosestHandSample(at time: TimeInterval, chirality: String) -> HandSample? {
        let filtered = handSamples.filter { $0.chirality == chirality }
        guard !filtered.isEmpty else { return nil }
        
        var closest = filtered[0]
        var minDiff = abs(filtered[0].timestamp - time)
        
        for sample in filtered {
            let diff = abs(sample.timestamp - time)
            if diff < minDiff {
                minDiff = diff
                closest = sample
            }
        }
        
        return closest
    }
    
    // MARK: - Interpolation
    private func interpolatePose(at time: TimeInterval) -> PoseSample? {
        guard !devicePoses.isEmpty else { return nil }
        
        // Find surrounding poses
        var prev = devicePoses.first!
        var next = devicePoses.first!
        
        for pose in devicePoses {
            if pose.t <= time { prev = pose }
            if pose.t >= time {
                next = pose
                break
            }
        }
        
        guard prev.t != next.t else { return prev }
        
        // Linear interpolation
        let t = Float((time - prev.t) / (next.t - prev.t))
        let interpPos = prev.p + (next.p - prev.p) * t
        let interpRot = simd_slerp(prev.q, next.q, t)
        
        return PoseSample(t: time, p: interpPos, q: interpRot, anchorID: nil)
    }
    
    private func interpolateSkeletonFrame(at time: TimeInterval) -> ImprovedSkeletonFrame? {
        guard !skeletonFrames.isEmpty else { return nil }
        
        // Find surrounding frames
        var prev = skeletonFrames.first!
        var next = skeletonFrames.first!
        
        for frame in skeletonFrames {
            if frame.timestamp <= time { prev = frame }
            if frame.timestamp >= time {
                next = frame
                break
            }
        }
        
        guard prev.timestamp != next.timestamp else { return prev }
        
        // Linear interpolation of all joints
        let t = Float((time - prev.timestamp) / (next.timestamp - prev.timestamp))
        
        return ImprovedSkeletonFrame(
            timestamp: time,
            head: lerp(prev.head, next.head, t),
            neck: lerp(prev.neck, next.neck, t),
            upperSpine: lerp(prev.upperSpine, next.upperSpine, t),
            lowerSpine: lerp(prev.lowerSpine, next.lowerSpine, t),
            shoulderAnchor: lerp(prev.shoulderAnchor, next.shoulderAnchor, t),
            leftShoulder: lerp(prev.leftShoulder, next.leftShoulder, t),
            rightShoulder: lerp(prev.rightShoulder, next.rightShoulder, t),
            leftElbow: lerp(prev.leftElbow, next.leftElbow, t),
            rightElbow: lerp(prev.rightElbow, next.rightElbow, t),
            leftWrist: lerp(prev.leftWrist, next.leftWrist, t),
            rightWrist: lerp(prev.rightWrist, next.rightWrist, t)
        )
    }
    
    private func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        return a + (b - a) * t
    }
}
