//// SimpleIKSolver.swift
//// Calculate skeleton joints from head (device) and hand positions only
//
//import Foundation
//import simd
//
//// MARK: - Skeleton Configuration
//struct BodyProportions {
//    // All measurements in meters
//    static let neckLength: Float = 0.15
//    static let upperTorsoLength: Float = 0.25
//    static let lowerTorsoLength: Float = 0.30
//    
//    static let shoulderOffset: Float = 0.20  // Distance from spine to each shoulder
//    static let upperArmLength: Float = 0.28
//    static let forearmLength: Float = 0.26
//    
//    static var totalTorsoLength: Float {
//        neckLength + upperTorsoLength + lowerTorsoLength
//    }
//}
//
//// MARK: - Skeleton Pose Result
//struct SkeletonFrame {
//    let timestamp: Double
//    
//    // Joint positions (world space)
//    var head: SIMD3<Float>
//    var neck: SIMD3<Float>
//    var upperSpine: SIMD3<Float>
//    var lowerSpine: SIMD3<Float>  // This is our ROOT
//    
//    var leftShoulder: SIMD3<Float>
//    var rightShoulder: SIMD3<Float>
//    
//    var leftElbow: SIMD3<Float>
//    var rightElbow: SIMD3<Float>
//    
//    var leftWrist: SIMD3<Float>
//    var rightWrist: SIMD3<Float>
//    
//    // Root transform (lower spine is the anchor)
//    var rootPosition: SIMD3<Float> {
//        return lowerSpine
//    }
//    
//    // Get all joints as dictionary for easy access
//    var allJoints: [String: SIMD3<Float>] {
//        return [
//            "head": head,
//            "neck": neck,
//            "upper_spine": upperSpine,
//            "lower_spine": lowerSpine,
//            "left_shoulder": leftShoulder,
//            "right_shoulder": rightShoulder,
//            "left_elbow": leftElbow,
//            "right_elbow": rightElbow,
//            "left_wrist": leftWrist,
//            "right_wrist": rightWrist
//        ]
//    }
//    
//    // Bone connections for line rendering
//    static let boneConnections: [(String, String)] = [
//        // Spine
//        ("head", "neck"),
//        ("neck", "upper_spine"),
//        ("upper_spine", "lower_spine"),
//        
//        // Shoulders
//        ("upper_spine", "left_shoulder"),
//        ("upper_spine", "right_shoulder"),
//        
//        // Left arm
//        ("left_shoulder", "left_elbow"),
//        ("left_elbow", "left_wrist"),
//        
//        // Right arm
//        ("right_shoulder", "right_elbow"),
//        ("right_elbow", "right_wrist")
//    ]
//}
//
//// MARK: - Simple IK Solver
//class SimpleIKSolver {
//    
//    /// Main solve function: takes head position and hand positions, returns full skeleton
//    static func solve(
//        headPosition: SIMD3<Float>,
//        headRotation: simd_quatf,
//        leftHandPosition: SIMD3<Float>?,
//        rightHandPosition: SIMD3<Float>?
//    ) -> SkeletonFrame {
//        
//        // 1. Calculate spine (working down from head)
//        let downVector = headRotation.act([0, -1, 0])  // Down direction in head's space
//        
//        let neck = headPosition + downVector * BodyProportions.neckLength
//        let upperSpine = neck + downVector * BodyProportions.upperTorsoLength
//        let lowerSpine = upperSpine + downVector * BodyProportions.lowerTorsoLength  // ROOT
//        
//        // 2. Calculate shoulders (offset from upper spine)
//        let rightVector = headRotation.act([1, 0, 0])
//        let leftShoulder = upperSpine + rightVector * (-BodyProportions.shoulderOffset)
//        let rightShoulder = upperSpine + rightVector * BodyProportions.shoulderOffset
//        
//        // 3. Calculate arms using two-bone IK
//        let leftElbow: SIMD3<Float>
//        let leftWrist: SIMD3<Float>
//        if let leftHand = leftHandPosition {
//            (leftElbow, leftWrist) = solveTwoBoneIK(
//                shoulder: leftShoulder,
//                hand: leftHand,
//                upperArmLength: BodyProportions.upperArmLength,
//                forearmLength: BodyProportions.forearmLength,
//                isLeftArm: true
//            )
//        } else {
//            // Default relaxed pose if no hand data
//            leftElbow = leftShoulder + [0, -0.25, 0.1]
//            leftWrist = leftElbow + [0, -0.25, 0.1]
//        }
//        
//        let rightElbow: SIMD3<Float>
//        let rightWrist: SIMD3<Float>
//        if let rightHand = rightHandPosition {
//            (rightElbow, rightWrist) = solveTwoBoneIK(
//                shoulder: rightShoulder,
//                hand: rightHand,
//                upperArmLength: BodyProportions.upperArmLength,
//                forearmLength: BodyProportions.forearmLength,
//                isLeftArm: false
//            )
//        } else {
//            // Default relaxed pose if no hand data
//            rightElbow = rightShoulder + [0, -0.25, -0.1]
//            rightWrist = rightElbow + [0, -0.25, -0.1]
//        }
//        
//        return SkeletonFrame(
//            timestamp: 0,
//            head: headPosition,
//            neck: neck,
//            upperSpine: upperSpine,
//            lowerSpine: lowerSpine,
//            leftShoulder: leftShoulder,
//            rightShoulder: rightShoulder,
//            leftElbow: leftElbow,
//            rightElbow: rightElbow,
//            leftWrist: leftWrist,
//            rightWrist: rightWrist
//        )
//    }
//    
//    // MARK: - Two-Bone IK (Shoulder -> Elbow -> Wrist)
//    private static func solveTwoBoneIK(
//        shoulder: SIMD3<Float>,
//        hand: SIMD3<Float>,
//        upperArmLength: Float,
//        forearmLength: Float,
//        isLeftArm: Bool
//    ) -> (elbow: SIMD3<Float>, wrist: SIMD3<Float>) {
//        
//        let shoulderToHand = hand - shoulder
//        let distance = simd_length(shoulderToHand)
//        let totalArmLength = upperArmLength + forearmLength
//        
//        // Clamp distance to arm reach (with slight margin to avoid overextension)
//        let clampedDistance = min(distance, totalArmLength * 0.99)
//        let direction = simd_normalize(shoulderToHand)
//        
//        // Use law of cosines to find angles
//        // cos(A) = (b² + c² - a²) / (2bc)
//        let upperSq = upperArmLength * upperArmLength
//        let forearmSq = forearmLength * forearmLength
//        let distSq = clampedDistance * clampedDistance
//        
//        // Angle at shoulder
//        let cosShoulderAngle = (upperSq + distSq - forearmSq) / (2.0 * upperArmLength * clampedDistance)
//        let shoulderAngle = acos(clamp(cosShoulderAngle, -1, 1))
//        
//        // Angle at elbow (interior angle)
//        let cosElbowAngle = (upperSq + forearmSq - distSq) / (2.0 * upperArmLength * forearmLength)
//        let elbowAngle = acos(clamp(cosElbowAngle, -1, 1))
//        
//        // Calculate elbow position
//        // We need a perpendicular axis to rotate around
//        let poleVector = isLeftArm ? SIMD3<Float>(1, -1, 0.5) : SIMD3<Float>(-1, -1, 0.5)
//        let rotationAxis = simd_normalize(simd_cross(direction, poleVector))
//        
//        // Rotate the direction by shoulder angle around the perpendicular axis
//        let upperArmRotation = simd_quatf(angle: shoulderAngle, axis: rotationAxis)
//        let upperArmDirection = upperArmRotation.act(direction)
//        
//        let elbow = shoulder + upperArmDirection * upperArmLength
//        let wrist = hand  // Wrist reaches to hand position
//        
//        return (elbow, wrist)
//    }
//    
//    // MARK: - Helper
//    private static func clamp(_ value: Float, _ minValue: Float, _ maxValue: Float) -> Float {
//        return max(minValue, min(maxValue, value))
//    }
//}
//
//// MARK: - Data Structures for CSV Loading
//struct HandSample {
//    let timestamp: Double
//    let chirality: String  // "left" or "right"
//    let wristPosition: SIMD3<Float>
//    
//    // All finger joint positions
//    let joints: [String: SIMD3<Float>]  // joint name -> position
//    
//    // Helper to get joint with chirality prefix
//    func getJoint(_ name: String) -> SIMD3<Float>? {
//        return joints[name]
//    }
//}
//
//// MARK: - Animation Timeline Builder
//class IKAnimationBuilder {
//    
//    /// Build complete animation timeline from device and hand data
//    static func buildTimeline(
//        devicePoses: [PoseSample],
//        handSamples: [HandSample]
//    ) -> [SkeletonFrame] {
//        
//        var frames: [SkeletonFrame] = []
//        
//        for devicePose in devicePoses {
//            let time = devicePose.t
//            
//            // Find closest hand samples for this timestamp
//            let leftHand = findClosestHand(at: time, chirality: "left", in: handSamples)
//            let rightHand = findClosestHand(at: time, chirality: "right", in: handSamples)
//            
//            // Solve IK
//            var frame = SimpleIKSolver.solve(
//                headPosition: devicePose.p,
//                headRotation: devicePose.q,
//                leftHandPosition: leftHand?.wristPosition,
//                rightHandPosition: rightHand?.wristPosition
//            )
//            
//            frame = SkeletonFrame(
//                timestamp: time,
//                head: frame.head,
//                neck: frame.neck,
//                upperSpine: frame.upperSpine,
//                lowerSpine: frame.lowerSpine,
//                leftShoulder: frame.leftShoulder,
//                rightShoulder: frame.rightShoulder,
//                leftElbow: frame.leftElbow,
//                rightElbow: frame.rightElbow,
//                leftWrist: frame.leftWrist,
//                rightWrist: frame.rightWrist
//            )
//            
//            frames.append(frame)
//        }
//        
//        print("✅ Built \(frames.count) skeleton frames from IK")
//        return frames
//    }
//    
//    private static func findClosestHand(
//        at timestamp: Double,
//        chirality: String,
//        in samples: [HandSample]
//    ) -> HandSample? {
//        
//        let filtered = samples.filter { $0.chirality == chirality }
//        guard !filtered.isEmpty else { return nil }
//        
//        var closest = filtered[0]
//        var minDiff = abs(filtered[0].timestamp - timestamp)
//        
//        for sample in filtered {
//            let diff = abs(sample.timestamp - timestamp)
//            if diff < minDiff {
//                minDiff = diff
//                closest = sample
//            }
//        }
//        
//        return closest
//    }
//}
