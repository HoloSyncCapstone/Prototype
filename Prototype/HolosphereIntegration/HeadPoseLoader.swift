import simd
import Foundation

struct HeadPose {
    let tMono: Double
    let tWall: Double
    let position: SIMD3<Float>
    let rotation: simd_quatf
}

class HeadPoseLoader {
    static func load(from path: String) -> [HeadPose] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let lines = content.components(separatedBy: .newlines).dropFirst()
        return lines.compactMap { line in
            let fields = line.split(separator: ",")
            guard fields.count == 9 else { return nil }
            let tMono = Double(fields[0]) ?? 0
            let tWall = Double(fields[1]) ?? 0
            let x = Float(fields[2]) ?? 0
            let y = Float(fields[3]) ?? 0
            let z = Float(fields[4]) ?? 0
            let qx = Float(fields[5]) ?? 0
            let qy = Float(fields[6]) ?? 0
            let qz = Float(fields[7]) ?? 0
            let qw = Float(fields[8]) ?? 1
            return HeadPose(
                tMono: tMono,
                tWall: tWall,
                position: SIMD3<Float>(x, y, z),
                rotation: simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
            )
        }
    }
}
