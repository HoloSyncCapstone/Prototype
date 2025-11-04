// ImprovedIKSolver.swift
// Better skeleton proportions with static shoulder anchor

import Foundation
import simd

// MARK: - Improved Body Proportions
struct ImprovedBodyProportions {
    // All measurements in meters (adjusted for better appearance)
    static let neckLength: Float = 0.10
    static let upperTorsoLength: Float = 0.20
    static let lowerTorsoLength: Float = 0.25
    
    // Shoulder system
    static let shoulderAnchorOffset: Float = 0.05  // Distance below upper_spine for shoulder anchor
    static let shoulderOffset: Float = 0.18         // Distance from anchor to each shoulder
    static let shoulderForwardOffset: Float = 0.03  // Slight forward position for natural posture
    
    // Arms
    static let upperArmLength: Float = 0.26
    static let forearmLength: Float = 0.24
    
    static var totalTorsoLength: Float {
        neckLength + upperTorsoLength + lowerTorsoLength
    }
}

// MARK: - Enhanced Skeleton Frame
struct ImprovedSkeletonFrame {
    let timestamp: Double
    
    // Core skeleton
    var head: SIMD3<Float>
    var neck: SIMD3<Float>
    var upperSpine: SIMD3<Float>
    var lowerSpine: SIMD3<Float>  // ROOT
    
    // Shoulder system (NEW!)
    var shoulderAnchor: SIMD3<Float>  // Static reference point
    var leftShoulder: SIMD3<Float>    // Rotates around anchor
    var rightShoulder: SIMD3<Float>   // Rotates around anchor
    
    // Arms
    var leftElbow: SIMD3<Float>
    var rightElbow: SIMD3<Float>
    var leftWrist: SIMD3<Float>
    var rightWrist: SIMD3<Float>
    
    var rootPosition: SIMD3<Float> {
        return lowerSpine
    }
    
    var allJoints: [String: SIMD3<Float>] {
        return [
            "head": head,
            "neck": neck,
            "upper_spine": upperSpine,
            "shoulder_anchor": shoulderAnchor,  // NEW
            "lower_spine": lowerSpine,
            "left_shoulder": leftShoulder,
            "right_shoulder": rightShoulder,
            "left_elbow": leftElbow,
            "right_elbow": rightElbow,
            "left_wrist": leftWrist,
            "right_wrist": rightWrist
        ]
    }
    
    // Updated bone connections
    static let boneConnections: [(String, String)] = [
        // Spine
        ("head", "neck"),
        ("neck", "upper_spine"),
        ("upper_spine", "shoulder_anchor"),  // NEW: spine to shoulder anchor
        ("shoulder_anchor", "lower_spine"),  // NEW: anchor to lower spine
        
        // Shoulders from anchor
        ("shoulder_anchor", "left_shoulder"),   // NEW: anchor to shoulders
        ("shoulder_anchor", "right_shoulder"),  // NEW: anchor to shoulders
        
        // Left arm
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_wrist"),
        
        // Right arm
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_wrist")
    ]
}

// MARK: - Improved IK Solver
class ImprovedIKSolver {
    
    static func solve(
        headPosition: SIMD3<Float>,
        headRotation: simd_quatf,
        leftHandPosition: SIMD3<Float>?,
        rightHandPosition: SIMD3<Float>?
    ) -> ImprovedSkeletonFrame {
        
        let downVector = headRotation.act([0, -1, 0])
        let rightVector = headRotation.act([1, 0, 0])
        let forwardVector = headRotation.act([0, 0, -1])
        
        // 1. Build spine from head down
        let neck = headPosition + downVector * ImprovedBodyProportions.neckLength
        let upperSpine = neck + downVector * ImprovedBodyProportions.upperTorsoLength
        
        // 2. NEW: Create shoulder anchor point (static reference)
        let shoulderAnchor = upperSpine + downVector * ImprovedBodyProportions.shoulderAnchorOffset
        
        // 3. Continue spine down from anchor
        let lowerSpine = shoulderAnchor + downVector * ImprovedBodyProportions.lowerTorsoLength
        
        // 4. Position shoulders relative to anchor (they rotate around this point)
        let shoulderForward = forwardVector * ImprovedBodyProportions.shoulderForwardOffset
        let leftShoulder = shoulderAnchor +
                          rightVector * (-ImprovedBodyProportions.shoulderOffset) +
                          shoulderForward
        let rightShoulder = shoulderAnchor +
                           rightVector * ImprovedBodyProportions.shoulderOffset +
                           shoulderForward
        
        // 5. Calculate arms with IK
        let leftElbow: SIMD3<Float>
        let leftWrist: SIMD3<Float>
        if let leftHand = leftHandPosition {
            (leftElbow, leftWrist) = solveTwoBoneIK(
                shoulder: leftShoulder,
                hand: leftHand,
                upperArmLength: ImprovedBodyProportions.upperArmLength,
                forearmLength: ImprovedBodyProportions.forearmLength,
                isLeftArm: true,
                shoulderAnchor: shoulderAnchor
            )
        } else {
            leftElbow = leftShoulder + [0, -0.20, 0]
            leftWrist = leftElbow + [0, -0.20, 0]
        }
        
        let rightElbow: SIMD3<Float>
        let rightWrist: SIMD3<Float>
        if let rightHand = rightHandPosition {
            (rightElbow, rightWrist) = solveTwoBoneIK(
                shoulder: rightShoulder,
                hand: rightHand,
                upperArmLength: ImprovedBodyProportions.upperArmLength,
                forearmLength: ImprovedBodyProportions.forearmLength,
                isLeftArm: false,
                shoulderAnchor: shoulderAnchor
            )
        } else {
            rightElbow = rightShoulder + [0, -0.20, 0]
            rightWrist = rightElbow + [0, -0.20, 0]
        }
        
        return ImprovedSkeletonFrame(
            timestamp: 0,
            head: headPosition,
            neck: neck,
            upperSpine: upperSpine,
            lowerSpine: lowerSpine,
            shoulderAnchor: shoulderAnchor,
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            leftElbow: leftElbow,
            rightElbow: rightElbow,
            leftWrist: leftWrist,
            rightWrist: rightWrist
        )
    }
    
    // MARK: - Improved Two-Bone IK
    private static func solveTwoBoneIK(
        shoulder: SIMD3<Float>,
        hand: SIMD3<Float>,
        upperArmLength: Float,
        forearmLength: Float,
        isLeftArm: Bool,
        shoulderAnchor: SIMD3<Float>
    ) -> (elbow: SIMD3<Float>, wrist: SIMD3<Float>) {
        
        let shoulderToHand = hand - shoulder
        let distance = simd_length(shoulderToHand)
        let totalArmLength = upperArmLength + forearmLength
        
        // Clamp to reachable distance
        let clampedDistance = min(distance, totalArmLength * 0.99)
        let direction = simd_normalize(shoulderToHand)
        
        // Law of cosines for angles
        let upperSq = upperArmLength * upperArmLength
        let forearmSq = forearmLength * forearmLength
        let distSq = clampedDistance * clampedDistance
        
        let cosShoulderAngle = (upperSq + distSq - forearmSq) / (2.0 * upperArmLength * clampedDistance)
        let shoulderAngle = acos(clamp(cosShoulderAngle, -1, 1))
        
        // Calculate pole vector (elbow hint direction)
        // Use shoulder anchor as reference for more stable elbow positioning
        let toAnchor = simd_normalize(shoulderAnchor - shoulder)
        let poleHint = isLeftArm ?
            SIMD3<Float>(-0.5, -1, 0.3) :  // Left elbow: out-left-down
            SIMD3<Float>(0.5, -1, 0.3)     // Right elbow: out-right-down
        
        // Blend pole hint with anchor direction for stability
        let blendedPole = simd_normalize(poleHint + toAnchor * 0.3)
        let rotationAxis = simd_normalize(simd_cross(direction, blendedPole))
        
        // Rotate direction by shoulder angle
        let upperArmRotation = simd_quatf(angle: shoulderAngle, axis: rotationAxis)
        let upperArmDirection = upperArmRotation.act(direction)
        
        let elbow = shoulder + upperArmDirection * upperArmLength
        let wrist = hand
        
        return (elbow, wrist)
    }
    
    private static func clamp(_ value: Float, _ minValue: Float, _ maxValue: Float) -> Float {
        return max(minValue, min(maxValue, value))
    }
}

// MARK: - Updated Animation Builder
class ImprovedAnimationBuilder {
    
    static func buildTimeline(
        devicePoses: [PoseSample],
        handSamples: [HandSample]
    ) -> [ImprovedSkeletonFrame] {
        
        var frames: [ImprovedSkeletonFrame] = []
        
        for devicePose in devicePoses {
            let time = devicePose.t
            
            let leftHand = findClosestHand(at: time, chirality: "left", in: handSamples)
            let rightHand = findClosestHand(at: time, chirality: "right", in: handSamples)
            
            var frame = ImprovedIKSolver.solve(
                headPosition: devicePose.p,
                headRotation: devicePose.q,
                leftHandPosition: leftHand?.wristPosition,
                rightHandPosition: rightHand?.wristPosition
            )
            
            frame = ImprovedSkeletonFrame(
                timestamp: time,
                head: frame.head,
                neck: frame.neck,
                upperSpine: frame.upperSpine,
                lowerSpine: frame.lowerSpine,
                shoulderAnchor: frame.shoulderAnchor,
                leftShoulder: frame.leftShoulder,
                rightShoulder: frame.rightShoulder,
                leftElbow: frame.leftElbow,
                rightElbow: frame.rightElbow,
                leftWrist: frame.leftWrist,
                rightWrist: frame.rightWrist
            )
            
            frames.append(frame)
        }
        
        print("✅ Built \(frames.count) improved skeleton frames with shoulder anchor")
        return frames
    }
    
    private static func findClosestHand(
        at timestamp: Double,
        chirality: String,
        in samples: [HandSample]
    ) -> HandSample? {
        
        let filtered = samples.filter { $0.chirality == chirality }
        guard !filtered.isEmpty else { return nil }
        
        var closest = filtered[0]
        var minDiff = abs(filtered[0].timestamp - timestamp)
        
        for sample in filtered {
            let diff = abs(sample.timestamp - timestamp)
            if diff < minDiff {
                minDiff = diff
                closest = sample
            }
        }
        
        return closest
    }
}

// MARK: - HandSample (same as before)
struct HandSample {
    let timestamp: Double
    let chirality: String
    let wristPosition: SIMD3<Float>
    let joints: [String: SIMD3<Float>]
    
    func getJoint(_ name: String) -> SIMD3<Float>? {
        return joints[name]
    }
}
