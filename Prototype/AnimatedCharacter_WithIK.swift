////
////  AnimatedCharacter_WithIK.swift
////  Prototype
////
////  Animated character using Full Body IK from head + hands data
////
//
//import Foundation
//import RealityKit
//import simd
//
//// MARK: - Animated Character with IK
//@MainActor
//class AnimatedCharacterWithIK {
//    
//    // The main character entity loaded from USD
//    private var characterEntity: Entity?
//    
//    // Joint references for animation
//    private var joints: [String: Entity] = [:]
//    
//    // Animation data - using IK-generated full body frames
//    private var fullBodyFrames: [FullBodyFrame] = []
//    
//    // Hand data for finger animation
//    private var handSamples: [EnhancedHandSample] = []
//    
//    // MARK: - Initialization
//    init() {}
//    
//    // MARK: - Load Character Model
//    func loadCharacter() async throws -> Entity {
//        guard let modelURL = Bundle.main.url(forResource: "final_low_poly_character__rigged", withExtension: "usdc") else {
//            throw NSError(domain: "AnimatedCharacter", code: 404,
//                         userInfo: [NSLocalizedDescriptionKey: "Character model not found"])
//        }
//        
//        let entity = try await Entity(contentsOf: modelURL)
//        characterEntity = entity
//        
//        // Find and cache all joint entities
//        cacheJointReferences(from: entity)
//        
//        print("✅ Loaded character with \(joints.count) joints")
//        return entity
//    }
//    
//    // MARK: - Cache Joint References
//    private func cacheJointReferences(from root: Entity) {
//        func findJoints(in entity: Entity) {
//            let name = entity.name.lowercased()
//            
//            // Store joints we'll animate
//            if name.contains("hips") || name.contains("spine") || name.contains("chest") ||
//               name.contains("neck") || name.contains("head") ||
//               name.contains("shoulder") || name.contains("arm") || name.contains("forearm") ||
//               name.contains("hand") || name.contains("thumb") || name.contains("index") ||
//               name.contains("middle") || name.contains("ring") || name.contains("pinky") ||
//               name.contains("palm") || name.contains("thigh") || name.contains("shin") ||
//               name.contains("foot") || name.contains("toe") {
//                joints[entity.name] = entity
//            }
//            
//            for child in entity.children {
//                findJoints(in: child)
//            }
//        }
//        
//        findJoints(in: root)
//    }
//    
//    // MARK: - Load Animation Data with IK
//    func loadAnimationDataWithIK(
//        devicePoses: [PoseSample],
//        handData: [HandJointSample]
//    ) {
//        // Convert hand data to enhanced format
//        handSamples = convertToEnhancedHandSamples(handData)
//        
//        // Build full-body timeline using IK solver
//        fullBodyFrames = FullBodyAnimationBuilder.buildTimeline(
//            devicePoses: devicePoses,
//            handSamples: handSamples
//        )
//        
//        print("✅ Loaded \(fullBodyFrames.count) full-body IK frames")
//    }
//    
//    // MARK: - Convert Hand Data
//    private func convertToEnhancedHandSamples(_ handData: [HandJointSample]) -> [EnhancedHandSample] {
//        var enhanced: [EnhancedHandSample] = []
//        
//        for sample in handData {
//            // Extract key positions
//            let wristKey = "\(sample.chirality)_wrist"
//            
//            guard let wrist = sample.joints[wristKey] else { continue }
//            
//            // For elbow, we need to estimate from wrist and shoulder direction
//            // Or use forearm data if available
//            let elbow = estimateElbowPosition(for: sample)
//            
//            let enhancedSample = EnhancedHandSample(
//                timestamp: sample.t,
//                chirality: sample.chirality,
//                wristPosition: wrist,
//                elbowPosition: elbow,
//                fingerPositions: sample.joints
//            )
//            
//            enhanced.append(enhancedSample)
//        }
//        
//        return enhanced
//    }
//    
//    private func estimateElbowPosition(for sample: HandJointSample) -> SIMD3<Float> {
//        let wristKey = "\(sample.chirality)_wrist"
//        guard let wrist = sample.joints[wristKey] else {
//            return SIMD3<Float>(0, 0, 0)
//        }
//        
//        // Estimate elbow as being ~0.25m up and slightly back from wrist
//        // This is a rough estimate - actual tracked elbow data would be better
//        let elbowOffset = SIMD3<Float>(0, 0.25, -0.1)
//        return wrist + elbowOffset
//    }
//    
//    // MARK: - Update Animation
//    func updateAnimation(at time: TimeInterval) {
//        guard let frame = interpolateFullBodyFrame(at: time) else { return }
//        
//        // Apply full body pose to character
//        applyFullBodyFrame(frame: frame)
//        
//        // Apply finger animation if available
//        if let handSample = interpolateHandSample(at: time, chirality: "right") {
//            applyFingerPose(sample: handSample, isLeft: false)
//        }
//        
//        if let handSample = interpolateHandSample(at: time, chirality: "left") {
//            applyFingerPose(sample: handSample, isLeft: true)
//        }
//    }
//    
//    // MARK: - Interpolate Full Body Frame
//    private func interpolateFullBodyFrame(at time: TimeInterval) -> FullBodyFrame? {
//        guard !fullBodyFrames.isEmpty else { return nil }
//        
//        var prevFrame = fullBodyFrames.first!
//        var nextFrame = fullBodyFrames.first!
//        
//        for i in 0..<fullBodyFrames.count {
//            if fullBodyFrames[i].timestamp <= time {
//                prevFrame = fullBodyFrames[i]
//            }
//            if fullBodyFrames[i].timestamp >= time {
//                nextFrame = fullBodyFrames[i]
//                break
//            }
//        }
//        
//        if prevFrame.timestamp == nextFrame.timestamp {
//            return prevFrame
//        }
//        
//        let t = Float((time - prevFrame.timestamp) / (nextFrame.timestamp - prevFrame.timestamp))
//        
//        // Interpolate all joints
//        return FullBodyFrame(
//            timestamp: time,
//            head: lerp(prevFrame.head, nextFrame.head, t),
//            neck: lerp(prevFrame.neck, nextFrame.neck, t),
//            upperSpine: lerp(prevFrame.upperSpine, nextFrame.upperSpine, t),
//            shoulderAnchor: lerp(prevFrame.shoulderAnchor, nextFrame.shoulderAnchor, t),
//            lowerSpine: lerp(prevFrame.lowerSpine, nextFrame.lowerSpine, t),
//            leftShoulder: lerp(prevFrame.leftShoulder, nextFrame.leftShoulder, t),
//            rightShoulder: lerp(prevFrame.rightShoulder, nextFrame.rightShoulder, t),
//            leftElbow: lerp(prevFrame.leftElbow, nextFrame.leftElbow, t),
//            rightElbow: lerp(prevFrame.rightElbow, nextFrame.rightElbow, t),
//            leftWrist: lerp(prevFrame.leftWrist, nextFrame.leftWrist, t),
//            rightWrist: lerp(prevFrame.rightWrist, nextFrame.rightWrist, t),
//            leftHip: lerp(prevFrame.leftHip, nextFrame.leftHip, t),
//            rightHip: lerp(prevFrame.rightHip, nextFrame.rightHip, t),
//            leftKnee: lerp(prevFrame.leftKnee, nextFrame.leftKnee, t),
//            rightKnee: lerp(prevFrame.rightKnee, nextFrame.rightKnee, t),
//            leftAnkle: lerp(prevFrame.leftAnkle, nextFrame.leftAnkle, t),
//            rightAnkle: lerp(prevFrame.rightAnkle, nextFrame.rightAnkle, t),
//            leftFoot: lerp(prevFrame.leftFoot, nextFrame.leftFoot, t),
//            rightFoot: lerp(prevFrame.rightFoot, nextFrame.rightFoot, t)
//        )
//    }
//    
//    // MARK: - Interpolate Hand Sample
//    private func interpolateHandSample(at time: TimeInterval, chirality: String) -> EnhancedHandSample? {
//        let filtered = handSamples.filter { $0.chirality == chirality }
//        guard !filtered.isEmpty else { return nil }
//        
//        var prevSample = filtered.first!
//        var nextSample = filtered.first!
//        
//        for i in 0..<filtered.count {
//            if filtered[i].timestamp <= time {
//                prevSample = filtered[i]
//            }
//            if filtered[i].timestamp >= time {
//                nextSample = filtered[i]
//                break
//            }
//        }
//        
//        if prevSample.timestamp == nextSample.timestamp {
//            return prevSample
//        }
//        
//        let t = Float((time - prevSample.timestamp) / (nextSample.timestamp - prevSample.timestamp))
//        
//        // Interpolate finger positions
//        var interpolatedFingers: [String: SIMD3<Float>] = [:]
//        for (key, prevPos) in prevSample.fingerPositions {
//            if let nextPos = nextSample.fingerPositions[key] {
//                interpolatedFingers[key] = lerp(prevPos, nextPos, t)
//            }
//        }
//        
//        return EnhancedHandSample(
//            timestamp: time,
//            chirality: chirality,
//            wristPosition: lerp(prevSample.wristPosition, nextSample.wristPosition, t),
//            elbowPosition: lerp(prevSample.elbowPosition, nextSample.elbowPosition, t),
//            fingerPositions: interpolatedFingers
//        )
//    }
//    
//    // MARK: - Apply Full Body Frame to Character
//    private func applyFullBodyFrame(frame: FullBodyFrame) {
//        // Map IK frame joints to character joints
//        
//        // Head
//        if let headJoint = findJoint(containing: "head") {
//            headJoint.position = frame.head
//        }
//        
//        // Neck
//        if let neckJoint = findJoint(containing: "neck") {
//            neckJoint.position = frame.neck
//        }
//        
//        // Spine
//        if let chestJoint = findJoint(containing: "chest") {
//            chestJoint.position = frame.upperSpine
//        }
//        
//        if let spineJoint = findJoint(named: "spine", excluding: ["upper", "lower", "chest"]) {
//            spineJoint.position = frame.shoulderAnchor
//        }
//        
//        if let hipsJoint = findJoint(containing: "hips") {
//            hipsJoint.position = frame.lowerSpine
//        }
//        
//        // Shoulders
//        if let leftShoulderJoint = findJoint(containing: "shoulder_L") {
//            leftShoulderJoint.position = frame.leftShoulder
//        }
//        
//        if let rightShoulderJoint = findJoint(containing: "shoulder_R") {
//            rightShoulderJoint.position = frame.rightShoulder
//        }
//        
//        // Arms
//        if let leftArmJoint = findJoint(containing: "upper_arm_L") {
//            // Position between shoulder and elbow
//            leftArmJoint.position = (frame.leftShoulder + frame.leftElbow) * 0.5
//        }
//        
//        if let rightArmJoint = findJoint(containing: "upper_arm_R") {
//            rightArmJoint.position = (frame.rightShoulder + frame.rightElbow) * 0.5
//        }
//        
//        // Forearms (elbows)
//        if let leftForearmJoint = findJoint(containing: "forearm_L") {
//            leftForearmJoint.position = frame.leftElbow
//        }
//        
//        if let rightForearmJoint = findJoint(containing: "forearm_R") {
//            rightForearmJoint.position = frame.rightElbow
//        }
//        
//        // Hands (wrists)
//        if let leftHandJoint = findJoint(containing: "hand_L") {
//            leftHandJoint.position = frame.leftWrist
//        }
//        
//        if let rightHandJoint = findJoint(containing: "hand_R") {
//            rightHandJoint.position = frame.rightWrist
//        }
//        
//        // === NEW: Lower Body ===
//        
//        // Thighs (hips)
//        if let leftThighJoint = findJoint(containing: "thigh_L") {
//            leftThighJoint.position = frame.leftHip
//        }
//        
//        if let rightThighJoint = findJoint(containing: "thigh_R") {
//            rightThighJoint.position = frame.rightHip
//        }
//        
//        // Shins (knees)
//        if let leftShinJoint = findJoint(containing: "shin_L") {
//            leftShinJoint.position = frame.leftKnee
//        }
//        
//        if let rightShinJoint = findJoint(containing: "shin_R") {
//            rightShinJoint.position = frame.rightKnee
//        }
//        
//        // Feet (ankles)
//        if let leftFootJoint = findJoint(containing: "foot_L") {
//            leftFootJoint.position = frame.leftAnkle
//        }
//        
//        if let rightFootJoint = findJoint(containing: "foot_R") {
//            rightFootJoint.position = frame.rightAnkle
//        }
//        
//        // Toes
//        if let leftToeJoint = findJoint(containing: "toe_L") {
//            leftToeJoint.position = frame.leftFoot
//        }
//        
//        if let rightToeJoint = findJoint(containing: "toe_R") {
//            rightToeJoint.position = frame.rightFoot
//        }
//    }
//    
//    // MARK: - Apply Finger Pose
//    private func applyFingerPose(sample: EnhancedHandSample, isLeft: Bool) {
//        let side = isLeft ? "L" : "R"
//        let prefix = isLeft ? "left" : "right"
//        
//        // Map finger tip positions
//        let fingerMap: [(csvName: String, jointPattern: String)] = [
//            ("\(prefix)_thumb_tip", "thumb_03_\(side)"),
//            ("\(prefix)_index_tip", "f_index_03_\(side)"),
//            ("\(prefix)_middle_tip", "f_middle_03_\(side)"),
//            ("\(prefix)_ring_tip", "f_ring_03_\(side)"),
//            ("\(prefix)_pinky_tip", "f_pinky_03_\(side)")
//        ]
//        
//        for (csvName, jointPattern) in fingerMap {
//            if let tipPos = sample.fingerPositions[csvName],
//               let tipJoint = findJoint(containing: jointPattern) {
//                tipJoint.position = tipPos
//            }
//        }
//        
//        // Map finger knuckles
//        let knuckleMap: [(csvName: String, jointPattern: String)] = [
//            ("\(prefix)_thumb_knuckle", "thumb_01_\(side)"),
//            ("\(prefix)_index_knuckle", "f_index_01_\(side)"),
//            ("\(prefix)_middle_knuckle", "f_middle_01_\(side)"),
//            ("\(prefix)_ring_knuckle", "f_ring_01_\(side)"),
//            ("\(prefix)_pinky_knuckle", "f_pinky_01_\(side)")
//        ]
//        
//        for (csvName, jointPattern) in knuckleMap {
//            if let knucklePos = sample.fingerPositions[csvName],
//               let knuckleJoint = findJoint(containing: jointPattern) {
//                knuckleJoint.position = knucklePos
//            }
//        }
//    }
//    
//    // MARK: - Find Joint Helpers
//    private func findJoint(containing substring: String) -> Entity? {
//        return joints.values.first { $0.name.lowercased().contains(substring.lowercased()) }
//    }
//    
//    private func findJoint(named name: String, excluding: [String]) -> Entity? {
//        return joints.values.first { joint in
//            let lowerName = joint.name.lowercased()
//            let lowerTarget = name.lowercased()
//            
//            guard lowerName.contains(lowerTarget) else { return false }
//            
//            for excluded in excluding {
//                if lowerName.contains(excluded.lowercased()) {
//                    return false
//                }
//            }
//            
//            return true
//        }
//    }
//    
//    // MARK: - Utility
//    private func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
//        return a + (b - a) * t
//    }
//    
//    // MARK: - Get Root Entity
//    func getRootEntity() -> Entity? {
//        return characterEntity
//    }
//}
