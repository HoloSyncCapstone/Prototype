// CharacterAnimatorWithFingers.swift
// Character animator with full finger tracking support

import RealityKit
import simd
import Foundation

class CharacterAnimatorWithFingers {
    
    private let characterEntity: Entity
    private var jointMapping: [String: Entity] = [:]
    private var debugMode: Bool = true
    
    init(characterEntity: Entity, debugMode: Bool = true) {
        self.characterEntity = characterEntity
        self.debugMode = debugMode
        findAllJoints()
        
        if debugMode {
            listAllJoints(in: characterEntity)
        }
    }
    
    // MARK: - Joint Discovery
    private func findAllJoints() {
        let jointPatterns: [String: [String]] = [
            // Head & Neck
            "head": ["head", "Head"],
            "neck": ["neck", "Neck"],
            

            // Spine
            "spine": ["upper_spine", "spine", "Spine"],
            "spine1": ["upper_spine"],
            "spine2": ["shoulder_anchor"],
            "hips": ["hips", "Hips", "lower_spine"],
            
            // Left Arm
            "left_shoulder": ["left_shoulder"],
            "left_upper_arm": ["left_upper_arm"],
            "left_elbow": ["left_forearm"],
            "left_wrist": ["left_hand"],
            
            // Right Arm
            "right_shoulder": ["right_shoulder"],
            "right_upper_arm": ["right_upper_arm"],
            "right_elbow": ["right_forearm"],
            "right_wrist": ["right_hand"],
            
            // Left Leg
            "left_hip": ["left_thigh"],
            "left_knee": ["left_shin"],
            "left_ankle": ["left_foot"],
            
            // Right Leg
            "right_hip": ["right_thigh"],
            "right_knee": ["right_shin"],
            "right_ankle": ["right_foot"],
            
            // Left Hand Fingers
            "left_thumb_knuckle": ["left_thumb_knuckle"],
            "left_thumb_intermediate": ["left_thumb_intermediate"],
            "left_thumb_tip": ["left_thumb_tip"],
            
            "left_index_knuckle": ["left_index_knuckle"],
            "left_index_intermediate_base": ["left_index_intermediate_base"],
            "left_index_intermediate_tip": ["left_index_intermediate_tip"],
            "left_index_tip": ["left_index_tip"],
            
            "left_middle_knuckle": ["left_middle_knuckle"],
            "left_middle_intermediate_base": ["left_middle_intermediate_base"],
            "left_middle_intermediate_tip": ["left_middle_intermediate_tip"],
            "left_middle_tip": ["left_middle_tip"],
            
            "left_ring_knuckle": ["left_ring_knuckle"],
            "left_ring_intermediate_base": ["left_ring_intermediate_base"],
            "left_ring_intermediate_tip": ["left_ring_intermediate_tip"],
            "left_ring_tip": ["left_ring_tip"],
            
            "left_little_knuckle": ["left_little_knuckle"],
            "left_little_intermediate_base": ["left_little_intermediate_base"],
            "left_little_intermediate_tip": ["left_little_intermediate_tip"],
            "left_little_tip": ["left_little_tip"],
            
            // Right Hand Fingers
            "right_thumb_knuckle": ["right_thumb_knuckle"],
            "right_thumb_intermediate": ["right_thumb_intermediate"],
            "right_thumb_tip": ["right_thumb_tip"],
            
            "right_index_knuckle": ["right_index_knuckle"],
            "right_index_intermediate_base": ["right_index_intermediate_base"],
            "right_index_intermediate_tip": ["right_index_intermediate_tip"],
            "right_index_tip": ["right_index_tip"],
            
            "right_middle_knuckle": ["right_middle_knuckle"],
            "right_middle_intermediate_base": ["right_middle_intermediate_base"],
            "right_middle_intermediate_tip": ["right_middle_intermediate_tip"],
            "right_middle_tip": ["right_middle_tip"],
            
            "right_ring_knuckle": ["right_ring_knuckle"],
            "right_ring_intermediate_base": ["right_ring_intermediate_base"],
            "right_ring_intermediate_tip": ["right_ring_intermediate_tip"],
            "right_ring_tip": ["right_ring_tip"],
            
            "right_little_knuckle": ["right_little_knuckle"],
            "right_little_intermediate_base": ["right_little_intermediate_base"],
            "right_little_intermediate_tip": ["right_little_intermediate_tip"],
            "right_little_tip": ["right_little_tip"]
        ]
        
        for (key, patterns) in jointPatterns {
            for pattern in patterns {
                if let joint = findJoint(named: pattern, in: characterEntity) {
                    jointMapping[key] = joint
                    if debugMode {
                        print("✅ Mapped \(key) -> \(joint.name)")
                    }
                    break
                }
            }
        }
        
        print("📍 Found and mapped \(jointMapping.count) character joints")
    }
    
    private func findJoint(named searchName: String, in entity: Entity) -> Entity? {
        let normalizedSearch = searchName.lowercased().replacingOccurrences(of: "_", with: "")
        let normalizedEntity = entity.name.lowercased().replacingOccurrences(of: "_", with: "")
        
        if normalizedEntity.contains(normalizedSearch) ||
           normalizedSearch.contains(normalizedEntity) ||
           normalizedEntity == normalizedSearch {
            return entity
        }
        
        for child in entity.children {
            if let found = findJoint(named: searchName, in: child) {
                return found
            }
        }
        
        return nil
    }
    
    // MARK: - Animation Update
    func update(from frame: FullBodyFrame, handData: (left: EnhancedHandSample?, right: EnhancedHandSample?)) {
        // Head & Neck
        updateJoint("head", position: frame.head)
        updateJoint("neck", position: frame.neck)
        
        // Spine
        updateJoint("spine", position: frame.upperSpine)
        updateJoint("spine1", position: frame.upperSpine)
        updateJoint("spine2", position: frame.shoulderAnchor)
        updateJoint("hips", position: frame.lowerSpine)
        
        // Left Arm
        updateJoint("left_shoulder", position: frame.leftShoulder)
        updateJoint("left_upper_arm", position: frame.leftShoulder)
        updateJoint("left_elbow", position: frame.leftElbow)
        updateJoint("left_wrist", position: frame.leftWrist)
        
        // Right Arm
        updateJoint("right_shoulder", position: frame.rightShoulder)
        updateJoint("right_upper_arm", position: frame.rightShoulder)
        updateJoint("right_elbow", position: frame.rightElbow)
        updateJoint("right_wrist", position: frame.rightWrist)
        
        // Left Leg
        updateJoint("left_hip", position: frame.leftHip)
        updateJoint("left_knee", position: frame.leftKnee)
        updateJoint("left_ankle", position: frame.leftAnkle)
        
        // Right Leg
        updateJoint("right_hip", position: frame.rightHip)
        updateJoint("right_knee", position: frame.rightKnee)
        updateJoint("right_ankle", position: frame.rightAnkle)
        
        // Update fingers
        if let leftHand = handData.left {
            updateFingers(hand: "left", joints: leftHand.joints)
        }
        
        if let rightHand = handData.right {
            updateFingers(hand: "right", joints: rightHand.joints)
        }
    }
    
    private func updateJoint(_ key: String, position: SIMD3<Float>) {
        jointMapping[key]?.position = position
    }
    
    private func updateFingers(hand: String, joints: [String: SIMD3<Float>]) {
        // Map CSV finger names to bone names
        let fingerMapping: [String: String] = [
            // Thumb
            "thumbKnuckle": "\(hand)_thumb_knuckle",
            "thumbIntermediateBase": "\(hand)_thumb_intermediate",
            "thumbTip": "\(hand)_thumb_tip",
            
            // Index
            "indexKnuckle": "\(hand)_index_knuckle",
            "indexIntermediateBase": "\(hand)_index_intermediate_base",
            "indexIntermediateTip": "\(hand)_index_intermediate_tip",
            "indexTip": "\(hand)_index_tip",
            
            // Middle
            "middleKnuckle": "\(hand)_middle_knuckle",
            "middleIntermediateBase": "\(hand)_middle_intermediate_base",
            "middleIntermediateTip": "\(hand)_middle_intermediate_tip",
            "middleTip": "\(hand)_middle_tip",
            
            // Ring
            "ringKnuckle": "\(hand)_ring_knuckle",
            "ringIntermediateBase": "\(hand)_ring_intermediate_base",
            "ringIntermediateTip": "\(hand)_ring_intermediate_tip",
            "ringTip": "\(hand)_ring_tip",
            
            // Little
            "littleKnuckle": "\(hand)_little_knuckle",
            "littleIntermediateBase": "\(hand)_little_intermediate_base",
            "littleIntermediateTip": "\(hand)_little_intermediate_tip",
            "littleTip": "\(hand)_little_tip"
        ]
        
        for (csvName, boneName) in fingerMapping {
            if let position = joints[csvName] {
                updateJoint(boneName, position: position)
            }
        }
    }
    
    // MARK: - Debug Utilities
    func listAllJoints(in entity: Entity, indent: String = "") {
        print("\(indent)📦 \(entity.name) [\(type(of: entity))]")
        
        for child in entity.children {
            listAllJoints(in: child, indent: indent + "  ")
        }
    }
    
    func getMappedJoints() -> [String] {
        return Array(jointMapping.keys).sorted()
    }
    
    func getMissingJoints() -> [String] {
        let expectedJoints = [
            "head", "neck", "spine", "hips",
            "left_shoulder", "left_elbow", "left_wrist",
            "right_shoulder", "right_elbow", "right_wrist",
            "left_hip", "left_knee", "left_ankle",
            "right_hip", "right_knee", "right_ankle"
        ]
        
        return expectedJoints.filter { jointMapping[$0] == nil }
    }
    
    func printDiagnostics() {
        print("\n=== Character Animator Diagnostics ===")
        print("Character: \(characterEntity.name)")
        print("Mapped joints: \(jointMapping.count)")
        print("\nFound joints:")
        for joint in getMappedJoints() {
            print("  ✅ \(joint)")
        }
        
        let missing = getMissingJoints()
        if !missing.isEmpty {
            print("\nMissing joints:")
            for joint in missing {
                print("  ❌ \(joint)")
            }
        }
        print("====================================\n")
    }
}

// MARK: - Helper Extensions
extension CharacterAnimatorWithFingers {
    
    func setScale(_ scale: Float) {
        characterEntity.scale = SIMD3<Float>(repeating: scale)
    }
    
    func setPosition(_ position: SIMD3<Float>) {
        characterEntity.position = position
    }
    
    func setRotation(_ rotation: simd_quatf) {
        characterEntity.orientation = rotation
    }
    
    func getEntity() -> Entity {
        return characterEntity
    }
}

// MARK: - Factory Method
extension CharacterAnimatorWithFingers {
    
    static func load(
        named resourceName: String,
        in bundle: Bundle = .main,
        debugMode: Bool = true
    ) async throws -> CharacterAnimatorWithFingers {
        
        guard let characterEntity = try? await Entity.load(
            named: resourceName,
            in: bundle
        ) else {
            throw CharacterAnimatorError.failedToLoad
        }
        
        let animator = CharacterAnimatorWithFingers(
            characterEntity: characterEntity,
            debugMode: debugMode
        )
        
        if debugMode {
            animator.printDiagnostics()
        }
        
        return animator
    }
}

enum CharacterAnimatorError: Error {
    case failedToLoad
    case missingRequiredJoints
}

// MARK: - Type Alias for Compatibility
typealias CharacterAnimator = CharacterAnimatorWithFingers
