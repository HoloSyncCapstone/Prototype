// FullBodyIKSolver.swift
// Complete body IK from ONLY head + hands data - WITH GROUND STABILIZATION

import Foundation
import simd

// MARK: - Body Proportions
struct BodyProportions {
    // Upper body
    static let neckLength: Float = 0.10
    static let upperTorsoLength: Float = 0.20
    static let lowerTorsoLength: Float = 0.25
    static let shoulderAnchorOffset: Float = 0.05
    static let shoulderOffset: Float = 0.18
    
    // Lower body
    static let hipWidth: Float = 0.18
    static let upperLegLength: Float = 0.2
    static let lowerLegLength: Float = 0.2
    static let footLength: Float = 0.25
    static let footHeight: Float = 0.08
    
    // Ground level (adjust based on your scene)
    static let groundLevel: Float = 0  // Y position of floor
    
    static var totalTorsoLength: Float {
        neckLength + upperTorsoLength + lowerTorsoLength
    }
    
    static var totalLegLength: Float {
        upperLegLength + lowerLegLength
    }
}

// MARK: - Complete Body Frame
struct FullBodyFrame {
    let timestamp: Double
    
    // Upper body
    var head: SIMD3<Float>
    var neck: SIMD3<Float>
    var upperSpine: SIMD3<Float>
    var shoulderAnchor: SIMD3<Float>
    var lowerSpine: SIMD3<Float>
    
    var leftShoulder: SIMD3<Float>
    var rightShoulder: SIMD3<Float>
    var leftElbow: SIMD3<Float>
    var rightElbow: SIMD3<Float>
    var leftWrist: SIMD3<Float>
    var rightWrist: SIMD3<Float>
    
    // Lower body
    var leftHip: SIMD3<Float>
    var rightHip: SIMD3<Float>
    var leftKnee: SIMD3<Float>
    var rightKnee: SIMD3<Float>
    var leftAnkle: SIMD3<Float>
    var rightAnkle: SIMD3<Float>
    var leftFoot: SIMD3<Float>
    var rightFoot: SIMD3<Float>
    
    var rootPosition: SIMD3<Float> {
        return lowerSpine
    }
    
    var allJoints: [String: SIMD3<Float>] {
        return [
            "head": head, "neck": neck, "upper_spine": upperSpine,
            "shoulder_anchor": shoulderAnchor, "lower_spine": lowerSpine,
            "left_shoulder": leftShoulder, "right_shoulder": rightShoulder,
            "left_elbow": leftElbow, "right_elbow": rightElbow,
            "left_wrist": leftWrist, "right_wrist": rightWrist,
            "left_hip": leftHip, "right_hip": rightHip,
            "left_knee": leftKnee, "right_knee": rightKnee,
            "left_ankle": leftAnkle, "right_ankle": rightAnkle,
            "left_foot": leftFoot, "right_foot": rightFoot
        ]
    }
    
    static let boneConnections: [(String, String)] = [
        ("head", "neck"), ("neck", "upper_spine"),
        ("upper_spine", "shoulder_anchor"), ("shoulder_anchor", "lower_spine"),
        ("shoulder_anchor", "left_shoulder"), ("shoulder_anchor", "right_shoulder"),
        ("left_shoulder", "left_elbow"), ("left_elbow", "left_wrist"),
        ("right_shoulder", "right_elbow"), ("right_elbow", "right_wrist"),
        ("lower_spine", "left_hip"), ("lower_spine", "right_hip"),
        ("left_hip", "left_knee"), ("left_knee", "left_ankle"), ("left_ankle", "left_foot"),
        ("right_hip", "right_knee"), ("right_knee", "right_ankle"), ("right_ankle", "right_foot")
    ]
}

// MARK: - Full Body IK Solver
class FullBodyIKSolver {
    
    static func solve(
        headPosition: SIMD3<Float>,
        headRotation: simd_quatf,
        leftHand: EnhancedHandSample?,
        rightHand: EnhancedHandSample?,
        previousFrame: FullBodyFrame? = nil
    ) -> FullBodyFrame {
        
        let downVector = headRotation.act([0, -1, 0])
        let rightVector = headRotation.act([1, 0, 0])
        let forwardVector = headRotation.act([0, 0, -1])
        
        // 1. UPPER BODY
        let neck = headPosition + downVector * BodyProportions.neckLength
        let upperSpine = neck + downVector * BodyProportions.upperTorsoLength
        let shoulderAnchor = upperSpine + downVector * BodyProportions.shoulderAnchorOffset
        let lowerSpine = shoulderAnchor + downVector * BodyProportions.lowerTorsoLength
        
        // 2. SHOULDERS
        let shoulderForward = forwardVector * 0.03
        let leftShoulder = shoulderAnchor + rightVector * (-BodyProportions.shoulderOffset) + shoulderForward
        let rightShoulder = shoulderAnchor + rightVector * BodyProportions.shoulderOffset + shoulderForward
        
        // 3. ARMS
        let leftElbow = leftHand?.elbowPosition ?? (leftShoulder + [0, -0.20, 0])
        let leftWrist = leftHand?.wristPosition ?? (leftElbow + [0, -0.20, 0])
        let rightElbow = rightHand?.elbowPosition ?? (rightShoulder + [0, -0.20, 0])
        let rightWrist = rightHand?.wristPosition ?? (rightElbow + [0, -0.20, 0])
        
        // 4. LOWER BODY - GROUNDED
        let lowerBody = estimateLowerBodyGrounded(
            rootPosition: lowerSpine,
            rootRotation: headRotation,
            leftHandPos: leftWrist,
            rightHandPos: rightWrist,
            previousFrame: previousFrame
        )
        
        return FullBodyFrame(
            timestamp: 0,
            head: headPosition, neck: neck, upperSpine: upperSpine,
            shoulderAnchor: shoulderAnchor, lowerSpine: lowerSpine,
            leftShoulder: leftShoulder, rightShoulder: rightShoulder,
            leftElbow: leftElbow, rightElbow: rightElbow,
            leftWrist: leftWrist, rightWrist: rightWrist,
            leftHip: lowerBody.leftHip, rightHip: lowerBody.rightHip,
            leftKnee: lowerBody.leftKnee, rightKnee: lowerBody.rightKnee,
            leftAnkle: lowerBody.leftAnkle, rightAnkle: lowerBody.rightAnkle,
            leftFoot: lowerBody.leftFoot, rightFoot: lowerBody.rightFoot
        )
    }
    
    // MARK: - Grounded Lower Body
    private static func estimateLowerBodyGrounded(
        rootPosition: SIMD3<Float>,
        rootRotation: simd_quatf,
        leftHandPos: SIMD3<Float>,
        rightHandPos: SIMD3<Float>,
        previousFrame: FullBodyFrame?
    ) -> LowerBodyJoints {
        
        let rightVector = rootRotation.act([1, 0, 0])
        let downVector = rootRotation.act([0, -1, 0])
        let forwardVector = rootRotation.act([0, 0, -1])
        
        // Use actual root position (don't lock)
        let hipCenter = rootPosition
        let leftHip = hipCenter + rightVector * (-BodyProportions.hipWidth / 2)
        let rightHip = hipCenter + rightVector * (BodyProportions.hipWidth / 2)
        
        // Determine standing vs sitting
        let avgHandHeight = (leftHandPos.y + rightHandPos.y) / 2
        let handsBelowHips = avgHandHeight < (hipCenter.y - 0.3)
        
        let groundLevel = BodyProportions.groundLevel
        
        let joints: LowerBodyJoints
        if handsBelowHips {
            joints = calculateStandingLegs(
                leftHip: leftHip,
                rightHip: rightHip,
                groundLevel: groundLevel,
                forwardVector: forwardVector,
                downVector: downVector
            )
        } else {
            joints = calculateSittingLegs(
                leftHip: leftHip,
                rightHip: rightHip,
                groundLevel: groundLevel,
                forwardVector: forwardVector,
                downVector: downVector
            )
        }
        
        // Smooth with previous frame
        return smoothJoints(joints, previous: previousFrame, factor: 0.2)
    }
    
    // MARK: - Calculate Standing Legs
    private static func calculateStandingLegs(
        leftHip: SIMD3<Float>,
        rightHip: SIMD3<Float>,
        groundLevel: Float,
        forwardVector: SIMD3<Float>,
        downVector: SIMD3<Float>
    ) -> LowerBodyJoints {
        
        let ankleHeight = groundLevel + BodyProportions.footHeight
        
        // Target ankle positions (on ground, below hips)
        var leftAnkleTarget = leftHip
        leftAnkleTarget.y = ankleHeight
        
        var rightAnkleTarget = rightHip
        rightAnkleTarget.y = ankleHeight
        
        // Calculate actual leg using two-bone IK
        let (leftKnee, leftAnkle) = solveTwoBoneIK(
            start: leftHip,
            end: leftAnkleTarget,
            upperLength: BodyProportions.upperLegLength,
            lowerLength: BodyProportions.lowerLegLength,
            bendDirection: forwardVector
        )
        
        let (rightKnee, rightAnkle) = solveTwoBoneIK(
            start: rightHip,
            end: rightAnkleTarget,
            upperLength: BodyProportions.upperLegLength,
            lowerLength: BodyProportions.lowerLegLength,
            bendDirection: forwardVector
        )
        
        // Feet on ground
        var leftFoot = leftAnkle
        leftFoot.y = groundLevel
        
        var rightFoot = rightAnkle
        rightFoot.y = groundLevel
        
        return LowerBodyJoints(
            leftHip: leftHip, rightHip: rightHip,
            leftKnee: leftKnee, rightKnee: rightKnee,
            leftAnkle: leftAnkle, rightAnkle: rightAnkle,
            leftFoot: leftFoot, rightFoot: rightFoot
        )
    }
    
    // MARK: - Calculate Sitting Legs
    private static func calculateSittingLegs(
        leftHip: SIMD3<Float>,
        rightHip: SIMD3<Float>,
        groundLevel: Float,
        forwardVector: SIMD3<Float>,
        downVector: SIMD3<Float>
    ) -> LowerBodyJoints {
        
        let ankleHeight = groundLevel + BodyProportions.footHeight
        
        // Ankles forward and on ground (sitting position)
        var leftAnkleTarget = leftHip + forwardVector * 0.3 + downVector * 0.5
        leftAnkleTarget.y = max(leftAnkleTarget.y, ankleHeight)
        
        var rightAnkleTarget = rightHip + forwardVector * 0.3 + downVector * 0.5
        rightAnkleTarget.y = max(rightAnkleTarget.y, ankleHeight)
        
        // Calculate legs
        let (leftKnee, leftAnkle) = solveTwoBoneIK(
            start: leftHip,
            end: leftAnkleTarget,
            upperLength: BodyProportions.upperLegLength,
            lowerLength: BodyProportions.lowerLegLength,
            bendDirection: forwardVector + downVector * 0.5
        )
        
        let (rightKnee, rightAnkle) = solveTwoBoneIK(
            start: rightHip,
            end: rightAnkleTarget,
            upperLength: BodyProportions.upperLegLength,
            lowerLength: BodyProportions.lowerLegLength,
            bendDirection: forwardVector + downVector * 0.5
        )
        
        // Feet on ground
        var leftFoot = leftAnkle
        leftFoot.y = groundLevel
        
        var rightFoot = rightAnkle
        rightFoot.y = groundLevel
        
        return LowerBodyJoints(
            leftHip: leftHip, rightHip: rightHip,
            leftKnee: leftKnee, rightKnee: rightKnee,
            leftAnkle: leftAnkle, rightAnkle: rightAnkle,
            leftFoot: leftFoot, rightFoot: rightFoot
        )
    }
    
    // MARK: - Two-Bone IK Solver
    private static func solveTwoBoneIK(
        start: SIMD3<Float>,
        end: SIMD3<Float>,
        upperLength: Float,
        lowerLength: Float,
        bendDirection: SIMD3<Float>
    ) -> (middle: SIMD3<Float>, actualEnd: SIMD3<Float>) {
        
        let startToEnd = end - start
        let distance = simd_length(startToEnd)
        let direction = distance > 0.001 ? startToEnd / distance : SIMD3<Float>(0, -1, 0)
        
        let maxReach = upperLength + lowerLength
        
        // If target is too far, stretch straight
        if distance >= maxReach * 0.99 {
            let middle = start + direction * upperLength
            let actualEnd = middle + direction * lowerLength
            return (middle, actualEnd)
        }
        
        // If target is too close, bend at minimum
        if distance < abs(upperLength - lowerLength) {
            let middle = start + direction * upperLength * 0.5
            let actualEnd = start + direction * distance
            return (middle, actualEnd)
        }
        
        // Use law of cosines
        let a = upperLength
        let b = lowerLength
        let c = distance
        
        // Angle at start joint
        let cosAngle = (a * a + c * c - b * b) / (2.0 * a * c)
        let angle = acos(min(1.0, max(-1.0, cosAngle)))
        
        // Find bend axis (perpendicular to start-end line)
        let bendDir = simd_normalize(bendDirection)
        var bendAxis = simd_cross(direction, bendDir)
        
        if simd_length(bendAxis) < 0.001 {
            // Fallback if parallel
            bendAxis = simd_cross(direction, SIMD3<Float>(1, 0, 0))
            if simd_length(bendAxis) < 0.001 {
                bendAxis = simd_cross(direction, SIMD3<Float>(0, 0, 1))
            }
        }
        bendAxis = simd_normalize(bendAxis)
        
        // Rotate direction by angle around bend axis
        let rotation = simd_quatf(angle: angle, axis: bendAxis)
        let upperDir = rotation.act(direction)
        
        let middle = start + upperDir * upperLength
        let actualEnd = end  // Use target end
        
        return (middle, actualEnd)
    }
    
    // MARK: - Temporal Smoothing
    private static func smoothJoints(
        _ current: LowerBodyJoints,
        previous: FullBodyFrame?,
        factor: Float
    ) -> LowerBodyJoints {
        
        guard let prev = previous else { return current }
        
        let s = factor  // 0.2 = 20% previous, 80% current
        
        return LowerBodyJoints(
            leftHip: prev.leftHip * s + current.leftHip * (1 - s),
            rightHip: prev.rightHip * s + current.rightHip * (1 - s),
            leftKnee: prev.leftKnee * s + current.leftKnee * (1 - s),
            rightKnee: prev.rightKnee * s + current.rightKnee * (1 - s),
            leftAnkle: prev.leftAnkle * s + current.leftAnkle * (1 - s),
            rightAnkle: prev.rightAnkle * s + current.rightAnkle * (1 - s),
            leftFoot: prev.leftFoot * s + current.leftFoot * (1 - s),
            rightFoot: prev.rightFoot * s + current.rightFoot * (1 - s)
        )
    }
}

// MARK: - Supporting Structures
private struct LowerBodyJoints {
    let leftHip: SIMD3<Float>
    let rightHip: SIMD3<Float>
    let leftKnee: SIMD3<Float>
    let rightKnee: SIMD3<Float>
    let leftAnkle: SIMD3<Float>
    let rightAnkle: SIMD3<Float>
    let leftFoot: SIMD3<Float>
    let rightFoot: SIMD3<Float>
}

// MARK: - Animation Builder
class FullBodyAnimationBuilder {
    
    static func buildTimeline(
        devicePoses: [PoseSample],
        handSamples: [EnhancedHandSample]
    ) -> [FullBodyFrame] {
        
        var frames: [FullBodyFrame] = []
        var previousFrame: FullBodyFrame? = nil
        
        for devicePose in devicePoses {
            let time = devicePose.t
            
            let leftHand = findClosestHand(at: time, chirality: "left", in: handSamples)
            let rightHand = findClosestHand(at: time, chirality: "right", in: handSamples)
            
            var frame = FullBodyIKSolver.solve(
                headPosition: devicePose.p,
                headRotation: devicePose.q,
                leftHand: leftHand,
                rightHand: rightHand,
                previousFrame: previousFrame
            )
            
            frame = FullBodyFrame(
                timestamp: time,
                head: frame.head, neck: frame.neck, upperSpine: frame.upperSpine,
                shoulderAnchor: frame.shoulderAnchor, lowerSpine: frame.lowerSpine,
                leftShoulder: frame.leftShoulder, rightShoulder: frame.rightShoulder,
                leftElbow: frame.leftElbow, rightElbow: frame.rightElbow,
                leftWrist: frame.leftWrist, rightWrist: frame.rightWrist,
                leftHip: frame.leftHip, rightHip: frame.rightHip,
                leftKnee: frame.leftKnee, rightKnee: frame.rightKnee,
                leftAnkle: frame.leftAnkle, rightAnkle: frame.rightAnkle,
                leftFoot: frame.leftFoot, rightFoot: frame.rightFoot
            )
            
            frames.append(frame)
            previousFrame = frame
        }
        
        print("✅ Built \(frames.count) GROUNDED FULL BODY frames using IK!")
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
