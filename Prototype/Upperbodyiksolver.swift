// RealDataIKSolver.swift
// Uses ACTUAL tracked elbow positions from hand_data instead of calculating them
// UPPER BODY

import Foundation
import simd

// MARK: - Body Proportions (now simpler - we have real elbow data!)
struct RealDataProportions {
    static let neckLength: Float = 0.10
    static let upperTorsoLength: Float = 0.20
    static let lowerTorsoLength: Float = 0.25
    
    static let shoulderAnchorOffset: Float = 0.05
    static let shoulderOffset: Float = 0.18
    static let shoulderForwardOffset: Float = 0.03
    
    // We don't need arm lengths anymore since we have real elbow positions!
}

// MARK: - Skeleton Frame with Real Data
struct RealDataSkeletonFrame {
    let timestamp: Double
    
    // Core skeleton
    var head: SIMD3<Float>
    var neck: SIMD3<Float>
    var upperSpine: SIMD3<Float>
    var lowerSpine: SIMD3<Float>
    
    // Shoulder system
    var shoulderAnchor: SIMD3<Float>
    var leftShoulder: SIMD3<Float>
    var rightShoulder: SIMD3<Float>
    
    // Arms - NOW USING REAL TRACKED DATA!
    var leftElbow: SIMD3<Float>   // From forearmArm in CSV
    var rightElbow: SIMD3<Float>  // From forearmArm in CSV
    var leftWrist: SIMD3<Float>   // From forearmWrist in CSV
    var rightWrist: SIMD3<Float>  // From forearmWrist in CSV
    
    var rootPosition: SIMD3<Float> {
        return lowerSpine
    }
    
    var allJoints: [String: SIMD3<Float>] {
        return [
            "head": head,
            "neck": neck,
            "upper_spine": upperSpine,
            "shoulder_anchor": shoulderAnchor,
            "lower_spine": lowerSpine,
            "left_shoulder": leftShoulder,
            "right_shoulder": rightShoulder,
            "left_elbow": leftElbow,
            "right_elbow": rightElbow,
            "left_wrist": leftWrist,
            "right_wrist": rightWrist
        ]
    }
    
    static let boneConnections: [(String, String)] = [
        ("head", "neck"),
        ("neck", "upper_spine"),
        ("upper_spine", "shoulder_anchor"),
        ("shoulder_anchor", "lower_spine"),
        ("shoulder_anchor", "left_shoulder"),
        ("shoulder_anchor", "right_shoulder"),
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_wrist"),
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_wrist")
    ]
}

// MARK: - Enhanced Hand Sample (with elbow!)
struct EnhancedHandSample {
    let timestamp: Double
    let chirality: String
    let elbowPosition: SIMD3<Float>  // NEW! From forearmArm
    let wristPosition: SIMD3<Float>  // From forearmWrist
    let joints: [String: SIMD3<Float>]  // All finger joints
}

// MARK: - Real Data IK Solver
class RealDataIKSolver {
    
    /// Solve skeleton using REAL tracked elbow positions (no IK needed for arms!)
    static func solve(
        headPosition: SIMD3<Float>,
        headRotation: simd_quatf,
        leftHand: EnhancedHandSample?,
        rightHand: EnhancedHandSample?
    ) -> RealDataSkeletonFrame {
        
        let downVector = headRotation.act([0, -1, 0])
        let rightVector = headRotation.act([1, 0, 0])
        let forwardVector = headRotation.act([0, 0, -1])
        
        // 1. Build spine
        let neck = headPosition + downVector * RealDataProportions.neckLength
        let upperSpine = neck + downVector * RealDataProportions.upperTorsoLength
        let shoulderAnchor = upperSpine + downVector * RealDataProportions.shoulderAnchorOffset
        let lowerSpine = shoulderAnchor + downVector * RealDataProportions.lowerTorsoLength
        
        // 2. Position shoulders
        let shoulderForward = forwardVector * RealDataProportions.shoulderForwardOffset
        let leftShoulder = shoulderAnchor +
                          rightVector * (-RealDataProportions.shoulderOffset) +
                          shoulderForward
        let rightShoulder = shoulderAnchor +
                           rightVector * RealDataProportions.shoulderOffset +
                           shoulderForward
        
        // 3. Use REAL elbow and wrist positions from tracking data!
        // No IK calculation needed - just use what we measured!
        let leftElbow = leftHand?.elbowPosition ?? (leftShoulder + [0, -0.20, 0])
        let leftWrist = leftHand?.wristPosition ?? (leftElbow + [0, -0.20, 0])
        
        let rightElbow = rightHand?.elbowPosition ?? (rightShoulder + [0, -0.20, 0])
        let rightWrist = rightHand?.wristPosition ?? (rightElbow + [0, -0.20, 0])
        
        return RealDataSkeletonFrame(
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
}

// MARK: - Animation Builder with Real Data
class RealDataAnimationBuilder {
    
    static func buildTimeline(
        devicePoses: [PoseSample],
        handSamples: [EnhancedHandSample]
    ) -> [RealDataSkeletonFrame] {
        
        var frames: [RealDataSkeletonFrame] = []
        
        for devicePose in devicePoses {
            let time = devicePose.t
            
            let leftHand = findClosestHand(at: time, chirality: "left", in: handSamples)
            let rightHand = findClosestHand(at: time, chirality: "right", in: handSamples)
            
            var frame = RealDataIKSolver.solve(
                headPosition: devicePose.p,
                headRotation: devicePose.q,
                leftHand: leftHand,
                rightHand: rightHand
            )
            
            frame = RealDataSkeletonFrame(
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
        
        print("✅ Built \(frames.count) skeleton frames using REAL tracked elbow positions!")
        return frames
    }
    
    private static func findClosestHand(
        at timestamp: Double,
        chirality: String,
        in samples: [EnhancedHandSample]
    ) -> EnhancedHandSample? {
        
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
