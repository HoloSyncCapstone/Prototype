//
//  SkeletonIO.swift
//  Prototype
//
//  Created by Patron on 10/15/25.
//

import Foundation
import simd

// MARK: - Skeleton Joint Sample
struct SkeletonJointSample {
    let frame: Int
    let timestamp: Double
    let joints: [String: SIMD3<Float>] // World-space positions
    let rotations: [String: simd_quatf] // World-space rotations (for head)
}

// MARK: - Skeleton Hierarchy Definition
struct SkeletonHierarchy {
    // Root joint - everything is relative to this
    static let rootJoint = "lower_spine"
    
    // Parent-child relationships for the skeleton
    static let hierarchy: [String: String?] = [
        // Spine chain (root has no parent)
        "lower_spine": nil,
        "mid_spine": "lower_spine",
        "upper_spine": "mid_spine",
        "neck": "upper_spine",
        "head": "neck",
        
        // Left arm chain
        "left_shoulder": "upper_spine",
        "left_elbow": "left_shoulder",
        "left_wrist": "left_elbow",
        
        // Right arm chain
        "right_shoulder": "upper_spine",
        "right_elbow": "right_shoulder",
        "right_wrist": "right_elbow",
        
        // Right hand fingers
        "right_thumbKnuckle": "right_wrist",
        "right_thumbIntermediateBase": "right_thumbKnuckle",
        "right_thumbIntermediateTip": "right_thumbIntermediateBase",
        "right_thumbTip": "right_thumbIntermediateTip",
        
        "right_indexFingerMetacarpal": "right_wrist",
        "right_indexFingerKnuckle": "right_indexFingerMetacarpal",
        "right_indexFingerIntermediateBase": "right_indexFingerKnuckle",
        "right_indexFingerIntermediateTip": "right_indexFingerIntermediateBase",
        "right_indexFingerTip": "right_indexFingerIntermediateTip",
        
        "right_middleFingerMetacarpal": "right_wrist",
        "right_middleFingerKnuckle": "right_middleFingerMetacarpal",
        "right_middleFingerIntermediateBase": "right_middleFingerKnuckle",
        "right_middleFingerIntermediateTip": "right_middleFingerIntermediateBase",
        "right_middleFingerTip": "right_middleFingerIntermediateTip",
        
        "right_ringFingerMetacarpal": "right_wrist",
        "right_ringFingerKnuckle": "right_ringFingerMetacarpal",
        "right_ringFingerIntermediateBase": "right_ringFingerKnuckle",
        "right_ringFingerIntermediateTip": "right_ringFingerIntermediateBase",
        "right_ringFingerTip": "right_ringFingerIntermediateTip",
        
        "right_littleFingerMetacarpal": "right_wrist",
        "right_littleFingerKnuckle": "right_littleFingerMetacarpal",
        "right_littleFingerIntermediateBase": "right_littleFingerKnuckle",
        "right_littleFingerIntermediateTip": "right_littleFingerIntermediateBase",
        "right_littleFingerTip": "right_littleFingerIntermediateTip",
        
        // Left hand fingers (mirror of right)
        "left_thumbKnuckle": "left_wrist",
        "left_thumbIntermediateBase": "left_thumbKnuckle",
        "left_thumbIntermediateTip": "left_thumbIntermediateBase",
        "left_thumbTip": "left_thumbIntermediateTip",
        
        "left_indexFingerMetacarpal": "left_wrist",
        "left_indexFingerKnuckle": "left_indexFingerMetacarpal",
        "left_indexFingerIntermediateBase": "left_indexFingerKnuckle",
        "left_indexFingerIntermediateTip": "left_indexFingerIntermediateBase",
        "left_indexFingerTip": "left_indexFingerIntermediateTip",
        
        "left_middleFingerMetacarpal": "left_wrist",
        "left_middleFingerKnuckle": "left_middleFingerMetacarpal",
        "left_middleFingerIntermediateBase": "left_middleFingerKnuckle",
        "left_middleFingerIntermediateTip": "left_middleFingerIntermediateBase",
        "left_middleFingerTip": "left_middleFingerIntermediateTip",
        
        "left_ringFingerMetacarpal": "left_wrist",
        "left_ringFingerKnuckle": "left_ringFingerMetacarpal",
        "left_ringFingerIntermediateBase": "left_ringFingerKnuckle",
        "left_ringFingerIntermediateTip": "left_ringFingerIntermediateBase",
        "left_ringFingerTip": "left_ringFingerIntermediateTip",
        
        "left_littleFingerMetacarpal": "left_wrist",
        "left_littleFingerKnuckle": "left_littleFingerMetacarpal",
        "left_littleFingerIntermediateBase": "left_littleFingerKnuckle",
        "left_littleFingerIntermediateTip": "left_littleFingerIntermediateBase",
        "left_littleFingerTip": "left_littleFingerIntermediateTip"
    ]
    
    // Get all bone connections for rendering
    static func getBoneConnections() -> [(parent: String, child: String)] {
        return hierarchy.compactMap { child, parent in
            guard let parent = parent else { return nil }
            return (parent: parent, child: child)
        }
    }
}

// MARK: - Skeleton CSV Loader
enum SkeletonCSVLoader {
    static func load(resource name: String, ext: String = "csv") -> [SkeletonJointSample] {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url) else {
            print("CSV not found: \(name).\(ext)")
            return []
        }

        var lines = text.split(whereSeparator: \.isNewline).map(String.init)
        
        // Remove header if present
        if let first = lines.first, first.lowercased().contains("frame") {
            lines.removeFirst()
        }

        var out: [SkeletonJointSample] = []
        out.reserveCapacity(lines.count)

        for line in lines {
            let c = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            
            guard c.count >= 35,
                  let frame = Int(c[0]),
                  let timestamp = Double(c[1]) else { continue }
            
            var joints: [String: SIMD3<Float>] = [:]
            var rotations: [String: simd_quatf] = [:]
            
            // Helper to parse position
            func parsePosition(_ indices: (Int, Int, Int)) -> SIMD3<Float>? {
                guard let x = Float(c[indices.0]),
                      let y = Float(c[indices.1]),
                      let z = Float(c[indices.2]) else { return nil }
                return SIMD3<Float>(x, y, z)
            }
            
            // Helper to parse quaternion
            func parseQuaternion(_ indices: (Int, Int, Int, Int)) -> simd_quatf? {
                guard let qx = Float(c[indices.0]),
                      let qy = Float(c[indices.1]),
                      let qz = Float(c[indices.2]),
                      let qw = Float(c[indices.3]) else { return nil }
                return simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
            }
            
            // Core skeleton joints
            if let pos = parsePosition((2, 3, 4)) { joints["head"] = pos }
            if let pos = parsePosition((5, 6, 7)) { joints["neck"] = pos }
            if let pos = parsePosition((8, 9, 10)) { joints["upper_spine"] = pos }
            if let pos = parsePosition((11, 12, 13)) { joints["mid_spine"] = pos }
            if let pos = parsePosition((14, 15, 16)) { joints["lower_spine"] = pos }
            if let pos = parsePosition((17, 18, 19)) { joints["left_shoulder"] = pos }
            if let pos = parsePosition((20, 21, 22)) { joints["right_shoulder"] = pos }
            if let pos = parsePosition((23, 24, 25)) { joints["right_elbow"] = pos }
            if let pos = parsePosition((26, 27, 28)) { joints["right_wrist"] = pos }
            
            // Head rotation (if available)
            if c.count > 32, let quat = parseQuaternion((29, 30, 31, 32)) {
                rotations["head"] = quat
            }
            
            // Right hand joints (starting from index 33)
            let rightHandJoints = [
                ("right_thumbKnuckle", 33), ("right_thumbIntermediateBase", 40),
                ("right_thumbIntermediateTip", 47), ("right_thumbTip", 54),
                ("right_indexFingerMetacarpal", 61), ("right_indexFingerKnuckle", 68),
                ("right_indexFingerIntermediateBase", 75), ("right_indexFingerIntermediateTip", 82),
                ("right_indexFingerTip", 89), ("right_middleFingerMetacarpal", 96),
                ("right_middleFingerKnuckle", 103), ("right_middleFingerIntermediateBase", 110),
                ("right_middleFingerIntermediateTip", 117), ("right_middleFingerTip", 124),
                ("right_ringFingerMetacarpal", 131), ("right_ringFingerKnuckle", 138),
                ("right_ringFingerIntermediateBase", 145), ("right_ringFingerIntermediateTip", 152),
                ("right_ringFingerTip", 159), ("right_littleFingerMetacarpal", 166),
                ("right_littleFingerKnuckle", 173), ("right_littleFingerIntermediateBase", 180),
                ("right_littleFingerIntermediateTip", 187), ("right_littleFingerTip", 194)
            ]
            
            for (name, startIdx) in rightHandJoints {
                if c.count > startIdx + 2, let pos = parsePosition((startIdx, startIdx + 1, startIdx + 2)) {
                    joints[name] = pos
                }
            }
            
            // Left hand joints (ONLY if data exists - check actual column count)
            // Note: In your CSV, left hand data appears to be missing/empty
            // Only left_elbow data exists at column 201
            if c.count > 203 {
                // Try to parse left elbow (column 201-203)
                if let pos = parsePosition((201, 202, 203)),
                   pos.x != 0 || pos.y != 0 || pos.z != 0 { // Check if not all zeros
                    joints["left_elbow"] = pos
                }
                
                // Try left wrist (column 204-206)
                if c.count > 206,
                   let pos = parsePosition((204, 205, 206)),
                   pos.x != 0 || pos.y != 0 || pos.z != 0 {
                    joints["left_wrist"] = pos
                }
            }
            
            // Left hand finger joints - only parse if columns exist
            let leftHandJoints = [
                ("left_thumbKnuckle", 207), ("left_thumbIntermediateBase", 214),
                ("left_thumbIntermediateTip", 221), ("left_thumbTip", 228),
                ("left_indexFingerMetacarpal", 235), ("left_indexFingerKnuckle", 242),
                ("left_indexFingerIntermediateBase", 249), ("left_indexFingerIntermediateTip", 256),
                ("left_indexFingerTip", 263), ("left_middleFingerMetacarpal", 270),
                ("left_middleFingerKnuckle", 277), ("left_middleFingerIntermediateBase", 284),
                ("left_middleFingerIntermediateTip", 291), ("left_middleFingerTip", 298),
                ("left_ringFingerMetacarpal", 305), ("left_ringFingerKnuckle", 312),
                ("left_ringFingerIntermediateBase", 319), ("left_ringFingerIntermediateTip", 326),
                ("left_ringFingerTip", 333), ("left_littleFingerMetacarpal", 340),
                ("left_littleFingerKnuckle", 347), ("left_littleFingerIntermediateBase", 354),
                ("left_littleFingerIntermediateTip", 361), ("left_littleFingerTip", 368)
            ]
            
            for (name, startIdx) in leftHandJoints {
                if c.count > startIdx + 2,
                   let pos = parsePosition((startIdx, startIdx + 1, startIdx + 2)),
                   pos.x != 0 || pos.y != 0 || pos.z != 0 { // Check if not empty
                    joints[name] = pos
                }
            }
            
            out.append(SkeletonJointSample(frame: frame, timestamp: timestamp, joints: joints, rotations: rotations))
        }

        // Normalize timestamps to start at 0
        if let t0 = out.first?.timestamp {
            out = out.map {
                SkeletonJointSample(frame: $0.frame, timestamp: $0.timestamp - t0, joints: $0.joints, rotations: $0.rotations)
            }
        }

        print("✅ Loaded \(out.count) complete skeleton samples with \(out.first?.joints.count ?? 0) joints")
        
        // Debug: Show which joints we actually loaded
        if let firstSample = out.first {
            let leftJoints = firstSample.joints.keys.filter { $0.contains("left_") }
            let rightJoints = firstSample.joints.keys.filter { $0.contains("right_") }
            let coreJoints = firstSample.joints.keys.filter { !$0.contains("left_") && !$0.contains("right_") }
            
            print("📊 Joint breakdown:")
            print("   Core skeleton: \(coreJoints.count) joints")
            print("   Right side: \(rightJoints.count) joints")
            print("   Left side: \(leftJoints.count) joints")
            
            if leftJoints.isEmpty {
                print("⚠️ WARNING: No left hand/arm data found in CSV!")
                print("   This is normal if only right hand was tracked during recording.")
            }
        }
        
        return out
    }
}
