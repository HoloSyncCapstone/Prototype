import Foundation
import RealityKit
import simd

// MARK: - CSV Animation Loader (Simplified - Focus on Hand Gestures Only)
class CSVAnimationLoader {
    
    private struct HandFrame {
        var time: TimeInterval
        var fingerCurls: [String: Float] // thumb, index, middle, ring, pinky
        var wristBend: Float
        var wristTwist: Float
    }
    
    // MARK: - Load Animation from CSV
    static func loadAnimation(from filename: String) async throws -> [Keyframe] {
        guard let csvData = try? await readCSVFile(filename) else {
            throw CSVLoadError.fileNotFound
        }
        
        let rows = parseCSV(csvData)
        guard rows.count > 1 else {
            throw CSVLoadError.emptyFile
        }
        
        let headers = rows[0]
        var handFrames: [HandFrame] = []
        
        let samplingRate = 5
        
        for (index, row) in rows.dropFirst().enumerated() {
            guard index % samplingRate == 0 else { continue }
            
            var rowData: [String: String] = [:]
            for (i, header) in headers.enumerated() {
                if i < row.count {
                    rowData[header.trimmingCharacters(in: .whitespacesAndNewlines)] = row[i]
                }
            }
            
            guard let timeString = rowData["t_mono"],
                  let time = Double(timeString),
                  let chirality = rowData["chirality"],
                  chirality.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "right" else {
                continue
            }
            
            // Extract finger curl amounts
            var fingerCurls: [String: Float] = [:]
            
            fingerCurls["thumb"] = calculateFingerCurl(rowData, finger: "thumb")
            fingerCurls["index"] = calculateFingerCurl(rowData, finger: "indexFinger")
            fingerCurls["middle"] = calculateFingerCurl(rowData, finger: "middleFinger")
            fingerCurls["ring"] = calculateFingerCurl(rowData, finger: "ringFinger")
            fingerCurls["pinky"] = calculateFingerCurl(rowData, finger: "littleFinger")
            
            // Extract wrist orientation (simplified)
            let (wristBend, wristTwist) = extractWristOrientation(rowData)
            
            handFrames.append(HandFrame(
                time: time,
                fingerCurls: fingerCurls,
                wristBend: wristBend,
                wristTwist: wristTwist
            ))
        }
        
        // Convert to keyframes
        var keyframes: [Keyframe] = []
        
        for frame in handFrames {
            var transforms: [String: Transform] = [:]
            
            // FIXED ARM POSE (looks good, from your hardcoded examples)
            // Keep everything from shoulder to wrist fixed for now
            transforms[rightShoulderName] = Transform(rotation: simd_quatf(angle: 0.8, axis: [0, 0, -1]))
            transforms[rightArmName] = Transform(rotation: simd_quatf(angle: -1.2, axis: [0, 1, 0]))
            transforms[rightForearmName] = Transform(rotation: simd_quatf(angle: 1.1, axis: [1, 0, 0]))
            
            // WRIST/HAND - Keep in neutral position for now
            // We can add wrist animation later once we figure out the coordinate mapping
            transforms[rightHandName] = Transform(rotation: simd_quatf(angle: 0.0, axis: [1, 0, 0]))
            
            // FINGERS - Map curl values to rotations
            // Thumb (different axis pattern)
            let thumbCurl = frame.fingerCurls["thumb"] ?? 0
            transforms[rightThumb1Name] = Transform(rotation: simd_quatf(angle: thumbCurl * 1.2, axis: [0, 0, -1]))
            transforms[rightThumb2Name] = Transform(rotation: simd_quatf(angle: thumbCurl * 1.0, axis: [-1, 0, 0]))
            
            // Index finger
            let indexCurl = frame.fingerCurls["index"] ?? 0
            transforms[rightIndex1Name] = Transform(rotation: simd_quatf(angle: indexCurl * 1.4, axis: [0, 0, -1]))
            transforms[rightIndex2Name] = Transform(rotation: simd_quatf(angle: indexCurl * 2.0, axis: [0, 0, -1]))
            
            // Middle finger
            let middleCurl = frame.fingerCurls["middle"] ?? 0
            transforms[rightMiddle1Name] = Transform(rotation: simd_quatf(angle: middleCurl * 1.4, axis: [0, 0, -1]))
            transforms[rightMiddle2Name] = Transform(rotation: simd_quatf(angle: middleCurl * 2.0, axis: [0, 0, -1]))
            
            // Ring finger
            let ringCurl = frame.fingerCurls["ring"] ?? 0
            transforms[rightRing1Name] = Transform(rotation: simd_quatf(angle: ringCurl * 1.4, axis: [0, 0, -1]))
            transforms[rightRing2Name] = Transform(rotation: simd_quatf(angle: ringCurl * 2.0, axis: [0, 0, -1]))
            
            // Pinky
            let pinkyCurl = frame.fingerCurls["pinky"] ?? 0
            transforms[rightPinky1Name] = Transform(rotation: simd_quatf(angle: pinkyCurl * 1.4, axis: [0, 0, -1]))
            transforms[rightPinky2Name] = Transform(rotation: simd_quatf(angle: pinkyCurl * 2.0, axis: [0, 0, -1]))
            
            keyframes.append(Keyframe(time: frame.time, pose: Pose(transforms: transforms)))
        }
        
        // Normalize times
        if let firstTime = keyframes.first?.time {
            keyframes = keyframes.map {
                Keyframe(time: $0.time - firstTime, pose: $0.pose)
            }
        }
        
        print("✅ Loaded \(keyframes.count) keyframes from CSV")
        return keyframes
    }
    
    // MARK: - Calculate Finger Curl (0 = open, 1 = closed)
    private static func calculateFingerCurl(_ rowData: [String: String], finger: String) -> Float {
        // Get positions of finger joints
        guard let knuckle = getPosition(rowData, prefix: "\(finger)Knuckle"),
              let intermediate = getPosition(rowData, prefix: "\(finger)IntermediateBase"),
              let tip = getPosition(rowData, prefix: "\(finger)Tip") else {
            return 0
        }
        
        // Calculate vectors along the finger bones
        let v1 = intermediate - knuckle
        let v2 = tip - intermediate
        
        // Normalize
        let n1 = normalize(v1)
        let n2 = normalize(v2)
        
        // Dot product tells us alignment
        // 1.0 = straight (vectors aligned)
        // -1.0 = curled (vectors opposite)
        let dot = simd_dot(n1, n2)
        
        // Map to 0-1 range
        // straight: dot ≈ 1, curl = 0
        // curled: dot ≈ -1, curl = 1
        let curl = (1.0 - dot) / 2.0
        
        return min(max(curl, 0.0), 1.0)
    }
    
    // MARK: - Extract Wrist Orientation
    private static func extractWristOrientation(_ rowData: [String: String]) -> (Float, Float) {
        guard let qx = Float(rowData["forearmWrist_qx"] ?? ""),
              let qy = Float(rowData["forearmWrist_qy"] ?? ""),
              let qz = Float(rowData["forearmWrist_qz"] ?? ""),
              let qw = Float(rowData["forearmWrist_qw"] ?? "") else {
            return (0, 0)
        }
        
        let quat = simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
        
        // Extract rotation components in local hand space
        // X-axis: along forearm (flexion/extension - bending up/down)
        // Z-axis: twist/pronation
        
        // Flexion/extension (X rotation in local space)
        let sinp = 2.0 * (quat.real * quat.imag.x + quat.imag.y * quat.imag.z)
        let cosp = 1.0 - 2.0 * (quat.imag.x * quat.imag.x + quat.imag.y * quat.imag.y)
        let flexion = atan2(sinp, cosp)
        
        // Radial/ulnar deviation (Z rotation in local space)
        let siny = 2.0 * (quat.real * quat.imag.y + quat.imag.z * quat.imag.x)
        let cosy = 1.0 - 2.0 * (quat.imag.y * quat.imag.y + quat.imag.z * quat.imag.z)
        let deviation = atan2(siny, cosy)
        
        return (flexion, deviation)
    }
    
    // MARK: - Helper Methods
    private static func getPosition(_ rowData: [String: String], prefix: String) -> SIMD3<Float>? {
        guard let px = Float(rowData["\(prefix)_px"] ?? ""),
              let py = Float(rowData["\(prefix)_py"] ?? ""),
              let pz = Float(rowData["\(prefix)_pz"] ?? "") else {
            return nil
        }
        return SIMD3<Float>(px, py, pz)
    }
    
    private static func readCSVFile(_ filename: String) async throws -> String {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "csv") else {
            throw CSVLoadError.fileNotFound
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    private static func parseCSV(_ csvString: String) -> [[String]] {
        var rows: [[String]] = []
        let lines = csvString.components(separatedBy: .newlines)
        
        for line in lines {
            guard !line.isEmpty else { continue }
            let columns = line.components(separatedBy: ",")
            rows.append(columns)
        }
        
        return rows
    }
}

// MARK: - Errors
enum CSVLoadError: Error {
    case fileNotFound
    case emptyFile
    case invalidFormat
}
