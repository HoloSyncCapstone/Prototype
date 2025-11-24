import Foundation
import SwiftUI

/// A data structure representing a key moment in a training session.
struct KeyMoment: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let time: TimeInterval
    let type: KeyMomentType

    /// An enumeration for the type of key moment, which determines its visual representation.
    enum KeyMomentType {
        case informational
        case location
        case warning
        case success

        /// The system image name for the key moment's icon.
        var systemImage: String {
            switch self {
            case .informational: return "info.circle.fill"
            case .location: return "mappin.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }

        /// The color associated with the key moment type.
        var color: Color {
            switch self {
            case .informational: return .purple
            case .location: return .blue
            case .warning: return .orange
            case .success: return .green
            }
        }
    }
}
