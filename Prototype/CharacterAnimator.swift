//// CharacterAnimator.swift
//// Animates rigged character model using IK data
//
//import RealityKit
//import simd
//import Foundation
//
//class CharacterAnimator {
//    
//    // MARK: - Properties
//    private let characterEntity: Entity
//    private var jointMapping: [String: Entity] = [:]
//    private var debugMode: Bool = true
//    
//    // MARK: - Initialization
//    init(characterEntity: Entity, debugMode: Bool = true) {
//        self.characterEntity = characterEntity
//        self.debugMode = debugMode
//        findAllJoints()
//        
//        if debugMode {
//            listAllJoints(in: characterEntity)
//        }
//    }
//    
//    // MARK: - Joint Discovery
//    private func findAllJoints() {
//        // Comprehensive list of possible joint names
//        // Covers: Mixamo, Humanoid, generic USD rigs
//        let jointPatterns: [String: [String]] = [
//            // Head & Neck
//            "head": ["joint_head"],
//            "neck": ["joint_neck"],
//            
//            // Spine
//            "spine": ["joint_spine"],
//            "spine1": ["joint_spine"],
//            "spine2": ["joint_spine"],
//            "hips": ["joint_hips", "metarig"],
//            
//            // Left Arm
//            "left_shoulder": ["joint_shoulder_L"],
//            "left_upper_arm": ["joint_upper_arm_L"],
//            "left_elbow": ["joint_forearm_L"],
//            "left_wrist": ["joint_hand_L"],
//            
//            // Right Arm
//            "right_shoulder": ["joint_shoulder_R"],
//            "right_upper_arm": ["joint_upper_arm_R"],
//            "right_elbow": ["joint_forearm_R"],
//            "right_wrist": ["joint_hand_R"],
//            
//            // Left Leg
//            "left_hip": ["joint_thigh_L"],
//            "left_knee": ["joint_shin_L"],
//            "left_ankle": ["joint_foot_L"],
//            
//            // Right Leg
//            "right_hip": ["joint_thigh_R"],
//            "right_knee": ["joint_shin_R"],
//            "right_ankle": ["joint_foot_R"]
//        ]
//        
//        // Try to find each joint
//        for (key, patterns) in jointPatterns {
//            for pattern in patterns {
//                if let joint = findJoint(named: pattern, in: characterEntity) {
//                    jointMapping[key] = joint
//                    if debugMode {
//                        print("✅ Mapped \(key) -> \(joint.name)")
//                    }
//                    break
//                }
//            }
//        }
//        
//        print("📍 Found and mapped \(jointMapping.count) character joints")
//    }
//    
//    private func findJoint(named searchName: String, in entity: Entity) -> Entity? {
//        // Normalize names for comparison (remove underscores, lowercase)
//        let normalizedSearch = searchName.lowercased().replacingOccurrences(of: "_", with: "")
//        let normalizedEntity = entity.name.lowercased().replacingOccurrences(of: "_", with: "")
//        
//        // Check if this entity matches
//        if normalizedEntity.contains(normalizedSearch) ||
//           normalizedSearch.contains(normalizedEntity) ||
//           normalizedEntity == normalizedSearch {
//            return entity
//        }
//        
//        // Search children recursively
//        for child in entity.children {
//            if let found = findJoint(named: searchName, in: child) {
//                return found
//            }
//        }
//        
//        return nil
//    }
//    
//    // MARK: - Animation Update
//    func update(from frame: FullBodyFrame) {
//        // Head & Neck
//        updateJoint("head", position: frame.head)
//        updateJoint("neck", position: frame.neck)
//        
//        // Spine
//        updateJoint("spine", position: frame.upperSpine)
//        updateJoint("spine1", position: frame.upperSpine)
//        updateJoint("spine2", position: frame.shoulderAnchor)
//        updateJoint("hips", position: frame.lowerSpine) // Root
//        
//        // Left Arm
//        updateJoint("left_shoulder", position: frame.leftShoulder)
//        updateJoint("left_upper_arm", position: frame.leftShoulder)
//        updateJoint("left_elbow", position: frame.leftElbow)
//        updateJoint("left_wrist", position: frame.leftWrist)
//        
//        // Right Arm
//        updateJoint("right_shoulder", position: frame.rightShoulder)
//        updateJoint("right_upper_arm", position: frame.rightShoulder)
//        updateJoint("right_elbow", position: frame.rightElbow)
//        updateJoint("right_wrist", position: frame.rightWrist)
//        
//        // Left Leg
//        updateJoint("left_hip", position: frame.leftHip)
//        updateJoint("left_knee", position: frame.leftKnee)
//        updateJoint("left_ankle", position: frame.leftAnkle)
//        updateJoint("left_toe", position: frame.leftFoot)
//        
//        // Right Leg
//        updateJoint("right_hip", position: frame.rightHip)
//        updateJoint("right_knee", position: frame.rightKnee)
//        updateJoint("right_ankle", position: frame.rightAnkle)
//        updateJoint("right_toe", position: frame.rightFoot)
//    }
//    
//    private func updateJoint(_ key: String, position: SIMD3<Float>) {
//        jointMapping[key]?.position = position
//    }
//    
//    // MARK: - Debug Utilities
//    func listAllJoints(in entity: Entity, indent: String = "") {
//        print("\(indent)📦 \(entity.name) [\(type(of: entity))]")
//        
//        for child in entity.children {
//            listAllJoints(in: child, indent: indent + "  ")
//        }
//    }
//    
//    func getMappedJoints() -> [String] {
//        return Array(jointMapping.keys).sorted()
//    }
//    
//    func getMissingJoints() -> [String] {
//        let expectedJoints = [
//            "head", "neck", "spine", "hips",
//            "left_shoulder", "left_elbow", "left_wrist",
//            "right_shoulder", "right_elbow", "right_wrist",
//            "left_hip", "left_knee", "left_ankle",
//            "right_hip", "right_knee", "right_ankle"
//        ]
//        
//        return expectedJoints.filter { jointMapping[$0] == nil }
//    }
//    
//    func printDiagnostics() {
//        print("\n=== Character Animator Diagnostics ===")
//        print("Character: \(characterEntity.name)")
//        print("Mapped joints: \(jointMapping.count)")
//        print("\nFound joints:")
//        for joint in getMappedJoints() {
//            print("  ✅ \(joint)")
//        }
//        
//        let missing = getMissingJoints()
//        if !missing.isEmpty {
//            print("\nMissing joints:")
//            for joint in missing {
//                print("  ❌ \(joint)")
//            }
//        }
//        print("====================================\n")
//    }
//}
//
//// MARK: - Helper Extensions
//extension CharacterAnimator {
//    
//    /// Scale the entire character
//    func setScale(_ scale: Float) {
//        characterEntity.scale = SIMD3<Float>(repeating: scale)
//    }
//    
//    /// Position the character in the scene
//    func setPosition(_ position: SIMD3<Float>) {
//        characterEntity.position = position
//    }
//    
//    /// Rotate the character
//    func setRotation(_ rotation: simd_quatf) {
//        characterEntity.orientation = rotation
//    }
//    
//    /// Get the character's root entity for direct manipulation
//    func getEntity() -> Entity {
//        return characterEntity
//    }
//}
//
//// MARK: - Factory Method
//extension CharacterAnimator {
//    
//    /// Load and create animator in one step
//    static func load(
//        named resourceName: String,
//        in bundle: Bundle = .main,
//        debugMode: Bool = true
//    ) async throws -> CharacterAnimator {
//        
//        guard let characterEntity = try? await Entity.load(
//            named: resourceName,
//            in: bundle
//        ) else {
//            throw CharacterAnimatorError.failedToLoad
//        }
//        
//        let animator = CharacterAnimator(
//            characterEntity: characterEntity,
//            debugMode: debugMode
//        )
//        
//        if debugMode {
//            animator.printDiagnostics()
//        }
//        
//        return animator
//    }
//}
//
//// MARK: - Errors
//enum CharacterAnimatorError: Error {
//    case failedToLoad
//    case missingRequiredJoints
//}
