import Foundation
import RealityKit
import simd

// MARK: - Data Structures

public struct Pose {
    public var transforms: [String: Transform] // key: joint prefix, e.g. "right_wrist"
}

public struct Keyframe {
    public var time: TimeInterval
    public var pose: Pose
}

public enum CSVAnimationError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case emptyData
    case malformedHeader
    case parseFailure(row: Int, column: Int, value: String)

    public var description: String {
        switch self {
        case .fileNotFound(let name): return "CSV file not found in bundle: \(name)"
        case .emptyData: return "CSV has no rows"
        case .malformedHeader: return "CSV header missing or malformed"
        case .parseFailure(let r, let c, let v):
            return "Failed to parse number at row \(r) col \(c): '\(v)'"
        }
    }
}

// MARK: - Loader

public final class CSVAnimationLoader {

    // Suffixes we support (both "x,y,z,qx,qy,qz,qw" and "px,py,pz,qx,qy,qz,qw")
    private static let posSuffixes = [ "_x", "_y", "_z", "_px", "_py", "_pz" ]
    private static let rotSuffixes = [ "_qx", "_qy", "_qz", "_qw" ]

    public struct ColumnMap {
        var pos: [String: (Int, Int, Int)] = [:]
        var rot: [String: (Int, Int, Int, Int)] = [:]
        var timeCol: Int? = nil
        var frameCol: Int? = nil
    }

    public static func loadFromBundle(resource: String,
                                      ext: String = "csv",
                                      expectedPrefixes: [String],
                                      defaultFPS: Double = 90.0) throws -> [Keyframe] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            throw CSVAnimationError.fileNotFound("\(resource).\(ext)")
        }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CSVAnimationError.emptyData
        }
        return try parseCSV(text: text, expectedPrefixes: expectedPrefixes, defaultFPS: defaultFPS)
    }

    public static func parseCSV(text: String,
                                expectedPrefixes: [String],
                                defaultFPS: Double = 90.0) throws -> [Keyframe] {
        var lines = text.split(whereSeparator: \.isNewline).map { String($0) }
        guard !lines.isEmpty else { throw CSVAnimationError.emptyData }

        let header = splitCSVRow(lines.removeFirst())
        guard !header.isEmpty else { throw CSVAnimationError.malformedHeader }

        let colMap = buildColumnMap(header: header, expectedPrefixes: expectedPrefixes)

        var keyframes: [Keyframe] = []
        keyframes.reserveCapacity(lines.count)

        for (i, raw) in lines.enumerated() {
            let cols = splitCSVRow(raw)
            if cols.count == 1 && cols[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            let t: TimeInterval = {
                if let tcol = colMap.timeCol, tcol < cols.count, let v = Double(cols[tcol]) {
                    return v
                } else if let fcol = colMap.frameCol, fcol < cols.count, let f = Double(cols[fcol]) {
                    return f / defaultFPS
                } else {
                    return Double(i) / defaultFPS
                }
            }()

            var transforms: [String: Transform] = [:]
            for joint in expectedPrefixes {
                var translation: SIMD3<Float>? = nil
                var rotation: simd_quatf? = nil

                if let (ix, iy, iz) = colMap.pos[joint],
                   ix < cols.count, iy < cols.count, iz < cols.count,
                   let x = Float(cols[ix]), let y = Float(cols[iy]), let z = Float(cols[iz]) {
                    translation = SIMD3<Float>(x, y, z)
                }

                if let (iqx, iqy, iqz, iqw) = colMap.rot[joint],
                   iqx < cols.count, iqy < cols.count, iqz < cols.count, iqw < cols.count,
                   let qx = Float(cols[iqx]), let qy = Float(cols[iqy]),
                   let qz = Float(cols[iqz]), let qw = Float(cols[iqw]) {
                    let q = normalizeIfNeeded(simd_quatf(ix: qx, iy: qy, iz: qz, r: qw))
                    rotation = q
                }

                if translation != nil || rotation != nil {
                    var T = Transform()
                    if let tr = translation { T.translation = tr }
                    if let r = rotation { T.rotation = r }
                    transforms[joint] = T
                }
            }

            keyframes.append(Keyframe(time: t, pose: Pose(transforms: transforms)))
        }

        keyframes.sort { $0.time < $1.time }
        return keyframes
    }

    private static func buildColumnMap(header: [String], expectedPrefixes: [String]) -> ColumnMap {
        var map = ColumnMap()
        if let idx = header.firstIndex(of: "t_mono") { map.timeCol = idx }
        if let idx = header.firstIndex(of: "frame") { map.frameCol = idx }

        for joint in expectedPrefixes {
            let xIdx = header.firstIndex(where: { $0 == "\(joint)_x" || $0 == "\(joint)_px" })
            let yIdx = header.firstIndex(where: { $0 == "\(joint)_y" || $0 == "\(joint)_py" })
            let zIdx = header.firstIndex(where: { $0 == "\(joint)_z" || $0 == "\(joint)_pz" })
            if let ix = xIdx, let iy = yIdx, let iz = zIdx {
                map.pos[joint] = (ix, iy, iz)
            }
            if let iqx = header.firstIndex(of: "\(joint)_qx"),
               let iqy = header.firstIndex(of: "\(joint)_qy"),
               let iqz = header.firstIndex(of: "\(joint)_qz"),
               let iqw = header.firstIndex(of: "\(joint)_qw") {
                map.rot[joint] = (iqx, iqy, iqz, iqw)
            }
        }
        return map
    }

    private static func splitCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for ch in row {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        result.append(current)
        return result
    }

    private static func normalizeIfNeeded(_ q: simd_quatf) -> simd_quatf {
        let len = simd_length(q.vector)
        guard len > 0 else { return simd_quatf(angle: 0, axis: [0,1,0]) }
        if abs(len - 1.0) < 1e-3 { return q }
        return simd_quatf(ix: q.imag.x/len, iy: q.imag.y/len, iz: q.imag.z/len, r: q.real/len)
    }
}
