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
    let joints: [String: SIMD3<Float>]
}

// MARK: - Skeleton CSV Loader
enum SkeletonCSVLoader {
    static func load(resource name: String,
                     ext: String = "csv") -> [SkeletonJointSample] {
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
            
            // Parse all joints from the CSV
            let jointDefinitions: [(name: String, xIndex: Int, yIndex: Int, zIndex: Int)] = [
                ("head", 2, 3, 4),
                ("neck", 5, 6, 7),
                ("upper_spine", 8, 9, 10),
                ("mid_spine", 11, 12, 13),
                ("lower_spine", 14, 15, 16),
                ("left_shoulder", 17, 18, 19),
                ("right_shoulder", 20, 21, 22),
                ("left_elbow", 23, 24, 25),
                ("right_elbow", 26, 27, 28),
                ("left_wrist", 29, 30, 31),
                ("right_wrist", 32, 33, 34)
            ]
            
            for jointDef in jointDefinitions {
                guard let x = Float(c[jointDef.xIndex]),
                      let y = Float(c[jointDef.yIndex]),
                      let z = Float(c[jointDef.zIndex]) else { continue }
                
                joints[jointDef.name] = SIMD3<Float>(x, y, z)
            }
            
            out.append(SkeletonJointSample(frame: frame, timestamp: timestamp, joints: joints))
        }

        // Normalize timestamps to start at 0
        if let t0 = out.first?.timestamp {
            out = out.map {
                SkeletonJointSample(frame: $0.frame, timestamp: $0.timestamp - t0, joints: $0.joints)
            }
        }

        print("✅ Loaded \(out.count) skeleton joint samples")
        return out
    }
}
