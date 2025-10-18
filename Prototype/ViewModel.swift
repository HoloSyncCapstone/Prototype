import Foundation
import Combine

// MARK: - Training Session Model
struct TrainingSession: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    let duration: TimeInterval
    let instructor: String
    let accuracyRate: Int
    let difficulty: Difficulty
    let category: Category
    let icon: String
    
    enum Difficulty: String {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }
    
    enum Category: String {
        case medical = "Medical"
        case aviation = "Aviation"
        case music = "Music"
        case engineering = "Engineering"
    }
    
    static func == (lhs: TrainingSession, rhs: TrainingSession) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - ViewModel
@MainActor
class ViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedSession: TrainingSession?
    @Published var isPlaying: Bool = false
    @Published var isSlowMotion: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var totalTime: TimeInterval = 15.0
    
    // MARK: - Properties
    let slowMotionFactor: Double = 0.25 // 25% speed when slow motion is on
    
    // MARK: - Available Sessions
    let trainingSessions: [TrainingSession] = [
        TrainingSession(
            name: "Surgical Suturing Technique",
            description: "Master the precise hand movements for interrupted suturing with haptic feedback integration",
            duration: 512.0,
            instructor: "Dr. Sarah Chen",
            accuracyRate: 94,
            difficulty: .advanced,
            category: .medical,
            icon: "🏥"
        ),
        TrainingSession(
            name: "Aircraft Engine Inspection",
            description: "Learn systematic visual and tactile inspection protocols for turbine engines",
            duration: 766.0,
            instructor: "Mike Rodriguez",
            accuracyRate: 87,
            difficulty: .intermediate,
            category: .aviation,
            icon: "✈️"
        ),
        TrainingSession(
            name: "Violin Bow Technique",
            description: "Fundamental bowing patterns and wrist movements for orchestral performance",
            duration: 376.0,
            instructor: "Elena Volkov",
            accuracyRate: 98,
            difficulty: .beginner,
            category: .music,
            icon: "🎻"
        ),
        TrainingSession(
            name: "Robotic Arm Calibration",
            description: "Precision calibration sequence for six-axis industrial robotic systems",
            duration: 1022.0,
            instructor: "Dr. James Liu",
            accuracyRate: 91,
            difficulty: .advanced,
            category: .engineering,
            icon: "🤖"
        ),
        TrainingSession(
            name: "Heart Surgery Preparation",
            description: "Pre-operative preparation techniques for cardiac interventional procedures",
            duration: 1125.0,
            instructor: "Dr. Maria Santos",
            accuracyRate: 98,
            difficulty: .advanced,
            category: .medical,
            icon: "❤️"
        ),
        TrainingSession(
            name: "Piano Performance",
            description: "Advanced finger positioning and dynamics for classical piano performance",
            duration: 573.0,
            instructor: "Chen Wei",
            accuracyRate: 89,
            difficulty: .intermediate,
            category: .music,
            icon: "🎹"
        )
    ]
    
    // MARK: - Session Management
    func selectSession(_ session: TrainingSession) {
        selectedSession = session
        // Reset playback state when selecting a new session
        currentTime = 0.0
        isPlaying = true
        isSlowMotion = false
    }
    
    func closeSession() {
        selectedSession = nil
        isPlaying = false
        currentTime = 0.0
        isSlowMotion = false
    }
    
    // MARK: - Playback Control
    func togglePlayback() {
        isPlaying.toggle()
    }
    
    func play() {
        isPlaying = true
    }
    
    func pause() {
        isPlaying = false
    }
    
    func rewind() {
        currentTime = 0.0
    }
    
    func toggleSlowMotion() {
        isSlowMotion.toggle()
    }
    
    // MARK: - Time Management
    func updateTime(_ deltaTime: TimeInterval) {
        guard isPlaying else { return }
        
        let adjustedDelta = isSlowMotion ? deltaTime * slowMotionFactor : deltaTime
        currentTime += adjustedDelta
        
        // Loop the animation
        if currentTime >= totalTime {
            currentTime = currentTime.truncatingRemainder(dividingBy: totalTime)
        }
    }
    
    func scrubTo(time: TimeInterval) {
        currentTime = min(max(0, time), totalTime)
    }
    
    // MARK: - Computed Properties
    var playbackSpeed: Double {
        return isSlowMotion ? slowMotionFactor : 1.0
    }
    
    var progressPercentage: Double {
        return totalTime > 0 ? currentTime / totalTime : 0
    }
}
