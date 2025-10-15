//
//  JointMapper.swift
//  Prototype
//
//  Created by Patron on 10/15/25.
//


// JointMapper.swift
import RealityKit

/// Maps CSV joint prefixes to model joint indices.
public struct JointMapper {
    public var prefixToPath: [String: String] = [:]
    public var pathToIndex: [String: Int] = [:]
    public var prefixToIndex: [String: Int] = [:]

    public init(model: ModelEntity) {
        // 1. Define manual mapping (your joint layout)
        prefixToPath = [
            // Spine / Head
            "lower_spine": "mixamorig6_Hips/mixamorig6_Spine",
            "mid_spine": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1",
            "upper_spine": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2",
            "neck": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_Neck",
            "head": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_Neck/mixamorig6_Head",

            // Left Arm
            "left_shoulder": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder",
            "left_elbow": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm",
            "left_wrist": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand",

            // Right Arm
            "right_shoulder": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder",
            "right_elbow": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm",
            "right_wrist": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand",

            // Right Hand — Thumb
            "right_thumbKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandThumb1",
            "right_thumbIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandThumb1/mixamorig6_RightHandThumb2",
            "right_thumbIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandThumb1/mixamorig6_RightHandThumb2/mixamorig6_RightHandThumb3",
            "right_thumbTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandThumb1/mixamorig6_RightHandThumb2/mixamorig6_RightHandThumb3/mixamorig6_RightHandThumb4",

            // Right Hand — Index
            "right_indexFingerKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandIndex1",
            "right_indexFingerIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandIndex1/mixamorig6_RightHandIndex2",
            "right_indexFingerIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandIndex1/mixamorig6_RightHandIndex2/mixamorig6_RightHandIndex3",
            "right_indexFingerTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandIndex1/mixamorig6_RightHandIndex2/mixamorig6_RightHandIndex3/mixamorig6_RightHandIndex4",

            // Right Hand — Middle
            "right_middleFingerKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandMiddle1",
            "right_middleFingerIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandMiddle1/mixamorig6_RightHandMiddle2",
            "right_middleFingerIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandMiddle1/mixamorig6_RightHandMiddle2/mixamorig6_RightHandMiddle3",
            "right_middleFingerTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandMiddle1/mixamorig6_RightHandMiddle2/mixamorig6_RightHandMiddle3/mixamorig6_RightHandMiddle4",

            // Right Hand — Ring
            "right_ringFingerKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandRing1",
            "right_ringFingerIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandRing1/mixamorig6_RightHandRing2",
            "right_ringFingerIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandRing1/mixamorig6_RightHandRing2/mixamorig6_RightHandRing3",
            "right_ringFingerTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandRing1/mixamorig6_RightHandRing2/mixamorig6_RightHandRing3/mixamorig6_RightHandRing4",

            // Right Hand — Pinky
            "right_littleFingerKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandPinky1",
            "right_littleFingerIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandPinky1/mixamorig6_RightHandPinky2",
            "right_littleFingerIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandPinky1/mixamorig6_RightHandPinky2/mixamorig6_RightHandPinky3",
            "right_littleFingerTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_RightShoulder/mixamorig6_RightArm/mixamorig6_RightForeArm/mixamorig6_RightHand/mixamorig6_RightHandPinky1/mixamorig6_RightHandPinky2/mixamorig6_RightHandPinky3/mixamorig6_RightHandPinky4",

            // Left Hand — Thumb
            "left_thumbKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandThumb1",
            "left_thumbIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandThumb1/mixamorig6_LeftHandThumb2",
            "left_thumbIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandThumb1/mixamorig6_LeftHandThumb2/mixamorig6_LeftHandThumb3",
            "left_thumbTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandThumb1/mixamorig6_LeftHandThumb2/mixamorig6_LeftHandThumb3/mixamorig6_LeftHandThumb4",

            // Left Hand — Index
            "left_indexFingerKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandIndex1",
            "left_indexFingerIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandIndex1/mixamorig6_LeftHandIndex2",
            "left_indexFingerIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandIndex1/mixamorig6_LeftHandIndex2/mixamorig6_LeftHandIndex3",
            "left_indexFingerTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandIndex1/mixamorig6_LeftHandIndex2/mixamorig6_LeftHandIndex3/mixamorig6_LeftHandIndex4",

            // Left Hand — Middle
            "left_middleFingerKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandMiddle1",
            "left_middleFingerIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandMiddle1/mixamorig6_LeftHandMiddle2",
            "left_middleFingerIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandMiddle1/mixamorig6_LeftHandMiddle2/mixamorig6_LeftHandMiddle3",
            "left_middleFingerTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandMiddle1/mixamorig6_LeftHandMiddle2/mixamorig6_LeftHandMiddle3/mixamorig6_LeftHandMiddle4",

            // Left Hand — Ring
            "left_ringFingerKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandRing1",
            "left_ringFingerIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandRing1/mixamorig6_LeftHandRing2",
            "left_ringFingerIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandRing1/mixamorig6_LeftHandRing2/mixamorig6_LeftHandRing3",
            "left_ringFingerTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandRing1/mixamorig6_LeftHandRing2/mixamorig6_LeftHandRing3/mixamorig6_LeftHandRing4",

            // Left Hand — Pinky
            "left_littleFingerKnuckle": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandPinky1",
            "left_littleFingerIntermediateBase": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandPinky1/mixamorig6_LeftHandPinky2",
            "left_littleFingerIntermediateTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandPinky1/mixamorig6_LeftHandPinky2/mixamorig6_LeftHandPinky3",
            "left_littleFingerTip": "mixamorig6_Hips/mixamorig6_Spine/mixamorig6_Spine1/mixamorig6_Spine2/mixamorig6_LeftShoulder/mixamorig6_LeftArm/mixamorig6_LeftForeArm/mixamorig6_LeftHand/mixamorig6_LeftHandPinky1/mixamorig6_LeftHandPinky2/mixamorig6_LeftHandPinky3/mixamorig6_LeftHandPinky4"
        ]

        // 2. Build path-to-index from the model
        for (i, path) in model.jointNames.enumerated() {
            pathToIndex[path] = i
        }

        // 3. Resolve prefix → index (skip those not found)
        for (prefix, path) in prefixToPath {
            if let idx = pathToIndex[path] {
                prefixToIndex[prefix] = idx
            } else {
                print("⚠️ Missing joint path in model: \(path) (for \(prefix))")
            }
        }

        print(" JointMapper built: \(prefixToIndex.count) joints matched.")
    }
}
