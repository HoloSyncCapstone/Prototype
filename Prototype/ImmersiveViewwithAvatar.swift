//// ImmersiveViewWithAvatar.swift
//// Complete avatar visualization with full body + finger tracking
//
//import SwiftUI
//import RealityKit
//import simd
//import Combine
//
//struct ImmersiveView: View {
//    @EnvironmentObject var viewModel: ViewModel
//    
//    // Animation data
//    @State private var skeletonFrames: [FullBodyFrame] = []
//    @State private var devicePoses: [PoseSample] = []
//    @State private var handSamples: [EnhancedHandSample] = []
//    
//    // Character animation
//    @State private var characterAnimator: CharacterAnimator?
//    @State private var showDebugVisualization: Bool = false  // Set to true to see debug spheres
//    
//    // Visual entities - Debug only
//    @State private var jointSpheres: [String: ModelEntity] = [:]
//    @State private var boneLines: [String: ModelEntity] = [:]
//    @State private var handJointSpheres: [String: ModelEntity] = [:]
//    @State private var fingerLines: [String: ModelEntity] = [:]
//    @State private var rootMarker: ModelEntity?
//    @State private var deviceCube: ModelEntity?
//    
//    // Animation timer
//    @State private var animationTimer: Timer?
//    
//    var body: some View {
//        RealityView { content, attachments in
//            setupScene(content: content)
//            
//            // Add playback controls
//            if let controls = attachments.entity(for: "controls") {
//                controls.position = [0, 1.5, -1.5]
//                content.add(controls)
//            }
//            
//            // Load character
//            loadCharacterSync(content: content)
//            
//            Task { @MainActor in
//                await loadDataAndSolveIK()
//                startAnimation()
//            }
//            
//        } attachments: {
//            Attachment(id: "controls") {
//                PlaybackControlsView()
//            }
//        }
//        .onDisappear {
//            animationTimer?.invalidate()
//        }
//    }
//    
//    // MARK: - Scene Setup
//    private func setupScene(content: RealityViewContent) {
//        // Add lighting
//        let light = DirectionalLight()
//        light.position = [5, 5, 5]
//        light.look(at: [0, 0, 0], from: light.position, relativeTo: nil)
//        light.light.intensity = 3000
//        content.add(light)
//        
//        // Optional: Add ground plane
//        let groundPlane = MeshResource.generatePlane(width: 5, depth: 5)
//        var groundMat = PhysicallyBasedMaterial()
//        groundMat.baseColor = .init(tint: .gray.withAlphaComponent(0.3))
//        let groundEntity = ModelEntity(mesh: groundPlane, materials: [groundMat])
//        groundEntity.position = [0, 0, 0]  // Ground at Y=0
//        content.add(groundEntity)
//        
//        // Create debug visualization if enabled
//        if showDebugVisualization {
//            createDebugVisualization(content: content)
//        }
//    }
//    
//    // MARK: - Load Character
//    @MainActor
//    private func loadCharacterSync(content: RealityViewContent) {
//        Task { @MainActor in
//            do {
//                print("🎭 Loading claudeavatar.usdc...")
//                
//                guard let characterEntity = try? await Entity.load(
//                    named: "claudeavatar",
//                    in: Bundle.main
//                ) else {
//                    print("⚠️ claudeavatar.usdc not found in bundle")
//                    print("   Make sure the file is added to your project target")
//                    return
//                }
//                
//                let animator = CharacterAnimator(
//                    characterEntity: characterEntity,
//                    debugMode: true
//                )
//                
//                content.add(characterEntity)
//                
//                // Position and scale character
//                characterEntity.position = [0, 0, -2]  // 2m in front
//                characterEntity.scale = [1, 1, 1]      // Adjust if needed
//                
//                self.characterAnimator = animator
//                
//                print("✅ Character loaded!")
//                animator.printDiagnostics()
//                
//            } catch {
//                print("⚠️ Error loading character: \(error)")
//            }
//        }
//    }
//    
//    // MARK: - Load Data and Solve IK
//    @MainActor
//    private func loadDataAndSolveIK() async {
//        print("📦 Loading data...")
//        
//        // Load device poses (head tracking)
//        devicePoses = PoseCSVLoader.load(resource: "device_pose_data_3")
//        print("✅ Loaded \(devicePoses.count) device poses")
//        
//        // Load hand data
//        handSamples = await loadHandData()
//        print("✅ Loaded \(handSamples.count) hand samples")
//        
//        // Solve IK for entire timeline
//        print("🤖 Solving IK...")
//        skeletonFrames = FullBodyAnimationBuilder.buildTimeline(
//            devicePoses: devicePoses,
//            handSamples: handSamples
//        )
//        
//        // Set animation duration
//        if let lastFrame = skeletonFrames.last {
//            viewModel.totalTime = lastFrame.timestamp
//        }
//        
//        print("⏱️ Animation duration: \(viewModel.totalTime)s")
//        print("🎬 Ready to play!")
//    }
//    
//    // MARK: - Load Hand Data
//    private func loadHandData() async -> [EnhancedHandSample] {
//        guard let url = Bundle.main.url(forResource: "hand_data_pivoted", withExtension: "csv"),
//              let csvText = try? String(contentsOf: url, encoding: .utf8) else {
//            print("❌ Could not load hand data")
//            return []
//        }
//        
//        let lines = csvText.components(separatedBy: .newlines)
//        guard lines.count > 1 else { return [] }
//        
//        let headers = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
//        var samples: [EnhancedHandSample] = []
//        
//        for line in lines.dropFirst() {
//            guard !line.isEmpty else { continue }
//            
//            let values = line.components(separatedBy: ",")
//            guard values.count >= 3 else { continue }
//            
//            var data: [String: String] = [:]
//            for (i, header) in headers.enumerated() {
//                if i < values.count {
//                    data[header] = values[i]
//                }
//            }
//            
//            guard let timeStr = data["t_mono"],
//                  let time = Double(timeStr),
//                  let chirality = data["chirality"]?.trimmingCharacters(in: .whitespaces).lowercased() else {
//                continue
//            }
//            
//            // Extract elbow position
//            guard let ex = Float(data["forearmArm_px"] ?? ""),
//                  let ey = Float(data["forearmArm_py"] ?? ""),
//                  let ez = Float(data["forearmArm_pz"] ?? "") else {
//                continue
//            }
//            let elbowPos = SIMD3<Float>(ex, ey, ez)
//            
//            // Extract wrist position
//            guard let wx = Float(data["forearmWrist_px"] ?? ""),
//                  let wy = Float(data["forearmWrist_py"] ?? ""),
//                  let wz = Float(data["forearmWrist_pz"] ?? "") else {
//                continue
//            }
//            let wristPos = SIMD3<Float>(wx, wy, wz)
//            
//            // Extract all finger joints
//            var joints: [String: SIMD3<Float>] = [:]
//            
//            let fingerJoints = [
//                "thumbKnuckle", "thumbIntermediateBase", "thumbIntermediateTip", "thumbTip",
//                "indexFingerKnuckle", "indexFingerIntermediateBase", "indexFingerIntermediateTip", "indexFingerTip",
//                "middleFingerKnuckle", "middleFingerIntermediateBase", "middleFingerIntermediateTip", "middleFingerTip",
//                "ringFingerKnuckle", "ringFingerIntermediateBase", "ringFingerIntermediateTip", "ringFingerTip",
//                "littleFingerKnuckle", "littleFingerIntermediateBase", "littleFingerIntermediateTip", "littleFingerTip"
//            ]
//            
//            for jointPrefix in fingerJoints {
//                if let px = Float(data["\(jointPrefix)_px"] ?? ""),
//                   let py = Float(data["\(jointPrefix)_py"] ?? ""),
//                   let pz = Float(data["\(jointPrefix)_pz"] ?? "") {
//                    
//                    // Simplify names: indexFingerKnuckle -> indexKnuckle
//                    let simpleName = jointPrefix
//                        .replacingOccurrences(of: "Finger", with: "")
//                    
//                    joints[simpleName] = SIMD3<Float>(px, py, pz)
//                }
//            }
//            
//            samples.append(EnhancedHandSample(
//                timestamp: time,
//                chirality: chirality,
//                elbowPosition: elbowPos,
//                wristPosition: wristPos,
//                joints: joints
//            ))
//        }
//        
//        // Normalize timestamps
//        if let firstTime = samples.first?.timestamp {
//            samples = samples.map {
//                EnhancedHandSample(
//                    timestamp: $0.timestamp - firstTime,
//                    chirality: $0.chirality,
//                    elbowPosition: $0.elbowPosition,
//                    wristPosition: $0.wristPosition,
//                    joints: $0.joints
//                )
//            }
//        }
//        
//        return samples
//    }
//    
//    // MARK: - Start Animation
//    private func startAnimation() {
//        animationTimer?.invalidate()
//        
//        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
//            Task { @MainActor in
//                guard viewModel.isPlaying else { return }
//                
//                viewModel.updateTime(1.0/60.0)
//                let currentTime = viewModel.currentTime
//                
//                // Get current skeleton frame
//                if let frame = interpolateSkeletonFrame(at: currentTime) {
//                    // Get current hand samples
//                    let leftHand = findClosestHandSample(at: currentTime, chirality: "left")
//                    let rightHand = findClosestHandSample(at: currentTime, chirality: "right")
//                    
//                    // Update character with body + hands
//                    characterAnimator?.update(from: frame, handData: (leftHand, rightHand))
//                    
//                    // Update debug visualization (if enabled)
//                    if showDebugVisualization {
//                        updateDebugVisualization(frame: frame, currentTime: currentTime)
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Find Closest Hand Sample
//    private func findClosestHandSample(at time: TimeInterval, chirality: String) -> EnhancedHandSample? {
//        let filtered = handSamples.filter { $0.chirality == chirality }
//        guard !filtered.isEmpty else { return nil }
//        
//        var closest = filtered[0]
//        var minDiff = abs(filtered[0].timestamp - time)
//        
//        for sample in filtered {
//            let diff = abs(sample.timestamp - time)
//            if diff < minDiff {
//                minDiff = diff
//                closest = sample
//            }
//        }
//        
//        return closest
//    }
//    
//    // MARK: - Interpolation
//    private func interpolateSkeletonFrame(at time: TimeInterval) -> FullBodyFrame? {
//        guard !skeletonFrames.isEmpty else { return nil }
//        
//        var prev = skeletonFrames.first!
//        var next = skeletonFrames.first!
//        
//        for frame in skeletonFrames {
//            if frame.timestamp <= time { prev = frame }
//            if frame.timestamp >= time {
//                next = frame
//                break
//            }
//        }
//        
//        guard prev.timestamp != next.timestamp else { return prev }
//        
//        let t = Float((time - prev.timestamp) / (next.timestamp - prev.timestamp))
//        
//        return FullBodyFrame(
//            timestamp: time,
//            head: lerp(prev.head, next.head, t),
//            neck: lerp(prev.neck, next.neck, t),
//            upperSpine: lerp(prev.upperSpine, next.upperSpine, t),
//            shoulderAnchor: lerp(prev.shoulderAnchor, next.shoulderAnchor, t),
//            lowerSpine: lerp(prev.lowerSpine, next.lowerSpine, t),
//            leftShoulder: lerp(prev.leftShoulder, next.leftShoulder, t),
//            rightShoulder: lerp(prev.rightShoulder, next.rightShoulder, t),
//            leftElbow: lerp(prev.leftElbow, next.leftElbow, t),
//            rightElbow: lerp(prev.rightElbow, next.rightElbow, t),
//            leftWrist: lerp(prev.leftWrist, next.leftWrist, t),
//            rightWrist: lerp(prev.rightWrist, next.rightWrist, t),
//            leftHip: lerp(prev.leftHip, next.leftHip, t),
//            rightHip: lerp(prev.rightHip, next.rightHip, t),
//            leftKnee: lerp(prev.leftKnee, next.leftKnee, t),
//            rightKnee: lerp(prev.rightKnee, next.rightKnee, t),
//            leftAnkle: lerp(prev.leftAnkle, next.leftAnkle, t),
//            rightAnkle: lerp(prev.rightAnkle, next.rightAnkle, t),
//            leftFoot: lerp(prev.leftFoot, next.leftFoot, t),
//            rightFoot: lerp(prev.rightFoot, next.rightFoot, t)
//        )
//    }
//    
//    private func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
//        return a + (b - a) * t
//    }
//    
//    // MARK: - Debug Visualization (Optional)
//    private func createDebugVisualization(content: RealityViewContent) {
//        // Create device cube
//        let cube = MeshResource.generateBox(size: [0.12, 0.08, 0.10])
//        var cubeMat = PhysicallyBasedMaterial()
//        cubeMat.baseColor = .init(tint: .white.withAlphaComponent(0.3))
//        let cubeEntity = ModelEntity(mesh: cube, materials: [cubeMat])
//        content.add(cubeEntity)
//        deviceCube = cubeEntity
//        
//        // Create root marker
//        let rootSphere = MeshResource.generateSphere(radius: 0.025)
//        var rootMat = PhysicallyBasedMaterial()
//        rootMat.baseColor = .init(tint: .red)
//        rootMat.emissiveColor = .init(color: .red)
//        rootMat.emissiveIntensity = 3.0
//        let root = ModelEntity(mesh: rootSphere, materials: [rootMat])
//        content.add(root)
//        rootMarker = root
//        
//        print("✅ Debug visualization created")
//    }
//    
//    private func updateDebugVisualization(frame: FullBodyFrame, currentTime: TimeInterval) {
//        // Update device cube
//        if let devicePose = interpolatePose(at: currentTime) {
//            deviceCube?.position = devicePose.p
//            deviceCube?.orientation = devicePose.q
//        }
//        
//        // Update root marker
//        rootMarker?.position = frame.rootPosition
//    }
//    
//    private func interpolatePose(at time: TimeInterval) -> PoseSample? {
//        guard !devicePoses.isEmpty else { return nil }
//        
//        var prev = devicePoses.first!
//        var next = devicePoses.first!
//        
//        for pose in devicePoses {
//            if pose.t <= time { prev = pose }
//            if pose.t >= time {
//                next = pose
//                break
//            }
//        }
//        
//        guard prev.t != next.t else { return prev }
//        
//        let t = Float((time - prev.t) / (next.t - prev.t))
//        let interpPos = prev.p + (next.p - prev.p) * t
//        let interpRot = simd_slerp(prev.q, next.q, t)
//        
//        return PoseSample(t: time, p: interpPos, q: interpRot, anchorID: nil)
//    }
//}
