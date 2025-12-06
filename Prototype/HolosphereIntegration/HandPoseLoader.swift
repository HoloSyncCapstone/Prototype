import simd
import Foundation

struct HandPose {
    let timestamp: Double
    let position: SIMD3<Float>
    let rotation: simd_quatf?  // Add rotation support for local coordinates
}

class HandPoseLoader {
    static func load(from path: String) -> [String: [String: [HandPose]]] {
        guard let content = try? String(contentsOfFile: path) else { return [:] }
        let lines = content.components(separatedBy: .newlines)
        var data: [String: [String: [HandPose]]] = [:]
        
        // Parse header to get column indices
        guard let headerLine = lines.first else { return [:] }
        let headers = headerLine.split(separator: ",").map { String($0) }
        
        // Create mapping from joint names to their column indices
        let jointNames = [
            "thumbKnuckle", "thumbIntermediateBase", "thumbIntermediateTip", "thumbTip",
            "indexFingerMetacarpal", "indexFingerKnuckle", "indexFingerIntermediateBase", 
            "indexFingerIntermediateTip", "indexFingerTip",
            "middleFingerMetacarpal", "middleFingerKnuckle", "middleFingerIntermediateBase",
            "middleFingerIntermediateTip", "middleFingerTip",
            "ringFingerMetacarpal", "ringFingerKnuckle", "ringFingerIntermediateBase",
            "ringFingerIntermediateTip", "ringFingerTip",
            "littleFingerMetacarpal", "littleFingerKnuckle", "littleFingerIntermediateBase",
            "littleFingerIntermediateTip", "littleFingerTip",
            "forearmWrist", "forearmArm"
        ]
        
        // Find column indices for each joint's position and rotation
        var jointColumns: [String: (px: Int, py: Int, pz: Int, qx: Int, qy: Int, qz: Int, qw: Int)] = [:]
        for jointName in jointNames {
            if let pxIndex = headers.firstIndex(of: "\(jointName)_px"),
               let pyIndex = headers.firstIndex(of: "\(jointName)_py"),
               let pzIndex = headers.firstIndex(of: "\(jointName)_pz"),
               let qxIndex = headers.firstIndex(of: "\(jointName)_qx"),
               let qyIndex = headers.firstIndex(of: "\(jointName)_qy"),
               let qzIndex = headers.firstIndex(of: "\(jointName)_qz"),
               let qwIndex = headers.firstIndex(of: "\(jointName)_qw") {
                jointColumns[jointName] = (pxIndex, pyIndex, pzIndex, qxIndex, qyIndex, qzIndex, qwIndex)
            }
        }
        
        // Find timestamp and chirality columns
        guard let tMonoIndex = headers.firstIndex(of: "t_mono"),
              let chiralityIndex = headers.firstIndex(of: "chirality") else {
            print("Required columns not found: t_mono, chirality")
            return [:]
        }
        
        // Process data lines
        for line in lines.dropFirst() { // skip header
            let fields = line.split(separator: ",").map { String($0) }
            guard fields.count == headers.count,
                  let timestamp = Double(fields[tMonoIndex]) else { continue }
            
            let chirality = fields[chiralityIndex]
            
            // Extract each joint's data
            for (jointName, columns) in jointColumns {
                guard let x = Float(fields[columns.px]),
                      let y = Float(fields[columns.py]),
                      let z = Float(fields[columns.pz]),
                      let qx = Float(fields[columns.qx]),
                      let qy = Float(fields[columns.qy]),
                      let qz = Float(fields[columns.qz]),
                      let qw = Float(fields[columns.qw]) else { continue }
                // let z = -zRaw
                let position = SIMD3<Float>(x, y, z)
                let rotation = simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
                let sample = HandPose(timestamp: timestamp, position: position, rotation: rotation)
                // FIXED: Correct chirality mapping - no more swapping
                data[chirality, default: [:]][jointName, default: []].append(sample)
            }
        }
        
        // Debug output
        print("\n=== Local Hand Data Loaded ===")
        for (chirality, joints) in data {
            print("Chirality: \(chirality)")
            for (jointName, samples) in joints {
                print("  \(jointName): \(samples.count) samples")
                if let first = samples.first {
                    print("    First sample: pos=\(first.position), rot=\(first.rotation?.vector ?? SIMD4<Float>(0,0,0,1))")
                }
            }
        }
        
        return data
    }
    
}
