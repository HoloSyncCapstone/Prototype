////
////  SkeletonIKSolver.swift
////  Prototype
////
////  Inverse Kinematics solver for full body skeleton
////
//
//import Foundation
//import simd
//
//// MARK: - Skeleton Configuration
//struct SkeletonConfig {
//    // Bone lengths (in meters, typical adult proportions)
//    static let neckLength: Float = 0.15
//    static let upperSpineLength: Float = 0.20
//    static let midSpineLength: Float = 0.18
//    static let lowerSpineLength: Float = 0.22
//    
//    static let shoulderWidth: Float = 0.40  // Distance from spine to shoulder
//    static let upperArmLength: Float = 0.30
//    static let forearmLength: Float = 0.28
//    
//    // Total spine length from head to hips
//    static var totalSpineLength: Float {
//        return neckLength + upperSpineLength + midSpineLength + lowerSpineLength
//    }
//}
//
//// MARK: - Complete Skeleton Pose
//struct SkeletonPose {
//    // Root transform (local anchor)
//    var rootPosition: SIMD3<Float>
//    var rootRotation: simd_quatf
//    
//    // All joint positions in world space
//    var joints: [String: SIMD3<Float>] = [:]
//    
//    // All joint rotations in world space
//    var rotations: [String: simd_quatf] = [:]
//    
//    init(rootPosition: SIMD3<Float> = .zero, rootRotation: simd_quatf = simd_quatf()) {
//        self.rootPosition = rootPosition
//        self.rootRotation = rootRotation
//    }
//    
//    // Convert world position to local space relative to root
//    func worldToLocal(_ worldPos: SIMD3<Float>) -> SIMD3<Float> {
//        let relative = worldPos - rootPosition
//        return simd_inverse(rootRotation).act(relative)
//    }
//    
//    // Convert local position to world space
//    func localToWorld(_ localPos: SIMD3<Float>) -> SIMD3<Float> {
//        return rootPosition + rootRotation.act(localPos)
//    }
//}
//
//// MARK: - IK Solver
//class SkeletonIKSolver {
//    
//    // MARK: - Main Solve Function
//    /// Solves the full skeleton given head position and hand positions
//    static func solve(
//        headPosition: SIMD3<Float>,
//        headRotation: simd_quatf,
//        rightHandPosition: SIMD3<Float>?,
//        leftHandPosition: SIMD3<Float>?
//    ) -> SkeletonPose {
//        
//        // 1. Establish root anchor at the lower spine (hips)
//        // The hips are directly below the head by the spine length
//        let spineDirection = headRotation.act([0, -1, 0]) // Down direction in head space
//        let hipsPosition = headPosition + spineDirection * SkeletonConfig.totalSpineLength
//        
//        var pose = SkeletonPose(rootPosition: hipsPosition, rootRotation: headRotation)
//        
//        // 2. Calculate spine joints (working up from hips to head)
//        calculateSpineJoints(
//            headPosition: headPosition,
//            headRotation: headRotation,
//            pose: &pose
//        )
//        
//        // 3. Calculate shoulder positions (at upper spine level)
//        calculateShoulders(pose: &pose, headRotation: headRotation)
//        
//        // 4. Calculate arm joints using IK if hand positions are provided
//        if let rightHand = rightHandPosition {
//            calculateArmIK(
//                side: .right,
//                shoulderPos: pose.joints["right_shoulder"]!,
//                handPos: rightHand,
//                pose: &pose
//            )
//        }
//        
//        if let leftHand = leftHandPosition {
//            calculateArmIK(
//                side: .left,
//                shoulderPos: pose.joints["left_shoulder"]!,
//                handPos: leftHand,
//                pose: &pose
//            )
//        }
//        
//        return pose
//    }
//    
//    // MARK: - Spine Calculation
//    private static func calculateSpineJoints(
//        headPosition: SIMD3<Float>,
//        headRotation: simd_quatf,
//        pose: inout SkeletonPose
//    ) {
//        // Work backwards from head to hips
//        let downDir = headRotation.act([0, -1, 0])
//        
//        var currentPos = headPosition
//        
//        // Head (already have this)
//        pose.joints["head"] = headPosition
//        pose.rotations["head"] = headRotation
//        
//        // Neck
//        currentPos = currentPos + downDir * SkeletonConfig.neckLength
//        pose.joints["neck"] = currentPos
//        pose.rotations["neck"] = headRotation
//        
//        // Upper spine
//        currentPos = currentPos + downDir * SkeletonConfig.upperSpineLength
//        pose.joints["upper_spine"] = currentPos
//        pose.rotations["upper_spine"] = headRotation
//        
//        // Mid spine
//        currentPos = currentPos + downDir * SkeletonConfig.midSpineLength
//        pose.joints["mid_spine"] = currentPos
//        pose.rotations["mid_spine"] = headRotation
//        
//        // Lower spine (should match root position)
//        currentPos = currentPos + downDir * SkeletonConfig.lowerSpineLength
//        pose.joints["lower_spine"] = currentPos
//        pose.rotations["lower_spine"] = headRotation
//        
//        // Verify root position matches
//        pose.rootPosition = currentPos
//    }
//    
//    // MARK: - Shoulder Calculation
//    private static func calculateShoulders(
//        pose: inout SkeletonPose,
//        headRotation: simd_quatf
//    ) {
//        guard let upperSpine = pose.joints["upper_spine"] else { return }
//        
//        // Shoulders are offset left and right from upper spine
//        let rightDir = headRotation.act([1, 0, 0])
//        let leftDir = headRotation.act([-1, 0, 0])
//        
//        // Slight forward offset for natural shoulder position
//        let forwardDir = headRotation.act([0, 0, -1])
//        let shoulderOffset = forwardDir * 0.05
//        
//        pose.joints["right_shoulder"] = upperSpine + rightDir * SkeletonConfig.shoulderWidth + shoulderOffset
//        pose.joints["left_shoulder"] = upperSpine + leftDir * SkeletonConfig.shoulderWidth + shoulderOffset
//        
//        pose.rotations["right_shoulder"] = headRotation
//        pose.rotations["left_shoulder"] = headRotation
//    }
//    
//    // MARK: - Arm IK (Two-Bone IK)
//    private enum ArmSide {
//        case left, right
//        
//        var prefix: String {
//            switch self {
//            case .left: return "left"
//            case .right: return "right"
//            }
//        }
//    }
//    
//    private static func calculateArmIK(
//        side: ArmSide,
//        shoulderPos: SIMD3<Float>,
//        handPos: SIMD3<Float>,
//        pose: inout SkeletonPose
//    ) {
//        let upperArmLength = SkeletonConfig.upperArmLength
//        let forearmLength = SkeletonConfig.forearmLength
//        let totalArmLength = upperArmLength + forearmLength
//        
//        // Vector from shoulder to hand
//        let shoulderToHand = handPos - shoulderPos
//        let distance = simd_length(shoulderToHand)
//        
//        // Clamp distance to be within reach
//        let clampedDistance = min(distance, totalArmLength * 0.99)
//        
//        // Normalize direction
//        let direction = simd_normalize(shoulderToHand)
//        
//        // Two-bone IK using law of cosines
//        // Calculate elbow position using the triangle formed by shoulder-elbow-hand
//        
//        // Angle at shoulder
//        let cosAngleA = (upperArmLength * upperArmLength + clampedDistance * clampedDistance - forearmLength * forearmLength) / (2.0 * upperArmLength * clampedDistance)
//        let angleA = acos(clamp(cosAngleA, -1, 1))
//        
//        // Angle at elbow (interior angle)
//        let cosAngleB = (upperArmLength * upperArmLength + forearmLength * forearmLength - clampedDistance * clampedDistance) / (2.0 * upperArmLength * forearmLength)
//        let elbowBend = acos(clamp(cosAngleB, -1, 1))
//        
//        // Calculate elbow position
//        // We need to rotate the upper arm direction by angleA around a perpendicular axis
//        let perpAxis = calculateElbowAxis(side: side, shoulderToHand: direction)
//        let upperArmRotation = simd_quatf(angle: angleA, axis: perpAxis)
//        let upperArmDirection = upperArmRotation.act(direction)
//        
//        let elbowPos = shoulderPos + upperArmDirection * upperArmLength
//        
//        // Store joint positions
//        pose.joints["\(side.prefix)_elbow"] = elbowPos
//        pose.joints["\(side.prefix)_wrist"] = handPos
//        
//        // Calculate rotations
//        let shoulderRotation = rotationFromDirection(upperArmDirection)
//        let forearmDirection = simd_normalize(handPos - elbowPos)
//        let elbowRotation = rotationFromDirection(forearmDirection)
//        
//        pose.rotations["\(side.prefix)_elbow"] = shoulderRotation
//        pose.rotations["\(side.prefix)_wrist"] = elbowRotation
//    }
//    
//    // MARK: - Helper Functions
//    
//    /// Calculate the axis around which the elbow bends
//    private static func calculateElbowAxis(side: ArmSide, shoulderToHand: SIMD3<Float>) -> SIMD3<Float> {
//        // For natural arm motion, the elbow typically bends in a plane
//        // The axis is perpendicular to the shoulder-hand direction
//        
//        // Use a bias direction based on side (elbows naturally point down and out)
//        let biasDirection: SIMD3<Float>
//        switch side {
//        case .right:
//            biasDirection = [0.5, -1, 0.3] // Down, slightly right, slightly back
//        case .left:
//            biasDirection = [-0.5, -1, 0.3] // Down, slightly left, slightly back
//        }
//        
//        // Calculate perpendicular axis
//        let perpAxis = simd_cross(shoulderToHand, biasDirection)
//        return simd_normalize(perpAxis)
//    }
//    
//    /// Create a quaternion that rotates the default direction to the target direction
//    private static func rotationFromDirection(_ direction: SIMD3<Float>) -> simd_quatf {
//        let defaultDir = SIMD3<Float>(0, -1, 0) // Default down direction
//        let axis = simd_cross(defaultDir, direction)
//        let axisLength = simd_length(axis)
//        
//        if axisLength < 0.001 {
//            // Directions are parallel
//            return simd_quatf()
//        }
//        
//        let normalizedAxis = axis / axisLength
//        let angle = acos(clamp(simd_dot(defaultDir, direction), -1, 1))
//        
//        return simd_quatf(angle: angle, axis: normalizedAxis)
//    }
//    
//    /// Clamp a value between min and max
//    private static func clamp(_ value: Float, _ minValue: Float, _ maxValue: Float) -> Float {
//        return max(minValue, min(maxValue, value))
//    }
//}
//
//// MARK: - Animation Timeline Integration
//struct IKAnimationFrame {
//    let timestamp: Double
//    let pose: SkeletonPose
//}
//
//class IKAnimationLoader {
//    
//    /// Load and solve IK for entire animation timeline
//    static func loadAndSolve(
//        devicePoses: [PoseSample],
//        handJointSamples: [HandJointSample]
//    ) -> [IKAnimationFrame] {
//        
//        var frames: [IKAnimationFrame] = []
//        
//        // For each device pose (head position), find corresponding hand positions and solve
//        for devicePose in devicePoses {
//            let timestamp = devicePose.t
//            
//            // Find closest hand sample by time
//            let handSample = findClosestHandSample(at: timestamp, in: handJointSamples)
//            
//            // Extract right and left wrist positions
//            let rightWrist = handSample?.joints["right_wrist"]
//            let leftWrist = handSample?.joints["left_wrist"]
//            
//            // Solve IK
//            let pose = SkeletonIKSolver.solve(
//                headPosition: devicePose.p,
//                headRotation: devicePose.q,
//                rightHandPosition: rightWrist,
//                leftHandPosition: leftWrist
//            )
//            
//            frames.append(IKAnimationFrame(timestamp: timestamp, pose: pose))
//        }
//        
//        print("✅ Generated \(frames.count) IK animation frames")
//        return frames
//    }
//    
//    private static func findClosestHandSample(
//        at timestamp: Double,
//        in samples: [HandJointSample]
//    ) -> HandJointSample? {
//        guard !samples.isEmpty else { return nil }
//        
//        var closest = samples[0]
//        var minDiff = abs(samples[0].t - timestamp)
//        
//        for sample in samples {
//            let diff = abs(sample.t - timestamp)
//            if diff < minDiff {
//                minDiff = diff
//                closest = sample
//            }
//        }
//        
//        return closest
//    }
//}
