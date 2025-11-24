import Foundation

/// An enumeration representing the different camera viewpoints available.
enum Viewpoint: String, CaseIterable, Identifiable {
    case firstPerson = "First Person"
    case thirdPerson = "Third Person"
    case topView = "Top View"
    case freeCamera = "Free Camera"

    /// The identifier for each viewpoint case.
    var id: String { self.rawValue }

    /// The system image name associated with each viewpoint.
    var systemImage: String {
        switch self {
        case .firstPerson:
            return "eye.fill"
        case .thirdPerson:
            return "person.fill"
        case .topView:
            return "arrow.up.left.and.arrow.down.right"
        case .freeCamera:
            return "camera.rotate"
        }
    }
}
