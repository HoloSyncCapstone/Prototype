//
//  PoseIO.swift
//  Prototype
//
//  Created by Patron on 10/8/25.
//

import Foundation
import simd

struct PoseSample {
    let t: Double           // timestamp
    let p: SIMD3<Float>     // position
    let q: simd_quatf       // rotation
    let anchorID: String?   // optional anchor id (only for object data)
}
enum PoseCSVLoader {
    static func load(resource name: String,
                     ext: String = "csv",
                     normalizeTime: Bool = true) -> [PoseSample] {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url) else {
            print("CSV not found: \(name).\(ext)")
            return []
        }

        var lines = text.split(whereSeparator: \.isNewline).map(String.init)
        if let first = lines.first, first.lowercased().contains("t_mono") {
            lines.removeFirst()
        }

        var out: [PoseSample] = []
        out.reserveCapacity(lines.count)

        for line in lines {
            let c = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            let hasAnchor = c.count == 10
            let anchorID = hasAnchor ? c[2] : nil
            let startIndex = hasAnchor ? 0 : 0

            guard let t = Double(c[0]),
                  let x = Float(c[hasAnchor ? 3 : 2]),
                  let y = Float(c[hasAnchor ? 4 : 3]),
                  let z = Float(c[hasAnchor ? 5 : 4]),
                  let qx = Float(c[hasAnchor ? 6 : 5]),
                  let qy = Float(c[hasAnchor ? 7 : 6]),
                  let qz = Float(c[hasAnchor ? 8 : 7]),
                  let qw = Float(c[hasAnchor ? 9 : 8]) else { continue }

            let p = SIMD3<Float>(x, y, z)
            let q = simd_quatf(ix: qx, iy: qy, iz: qz, r: qw)
            out.append(PoseSample(t: t, p: p, q: simd_normalize(q), anchorID: anchorID))
        }

        // normalize only if asked
        if normalizeTime, let t0 = out.first?.t {
            out = out.map {
                PoseSample(t: $0.t - t0, p: $0.p, q: $0.q, anchorID: $0.anchorID)
            }
        }

        return out
    }
}
