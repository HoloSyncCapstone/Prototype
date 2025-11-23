import Foundation
import Combine

// MARK: - Training Session Model
struct TrainingSession: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    let duration: TimeInterval
    
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
    
    // MARK: - Audio Manager
    let audioManager = AudioPlayerManager()
    
    // MARK: - Properties
    let slowMotionFactor: Double = 0.25 // 25% speed when slow motion is on
    
    // MARK: - Available Sessions
    let trainingSessions: [TrainingSession] = [
        TrainingSession(
            name: "Hand Signals",
            description: "Learn basic hand signal animations",
            duration: 15.0
        ),
        TrainingSession(
            name: "Advanced Gestures",
            description: "Master complex gesture sequences",
            duration: 15.0
        ),
        TrainingSession(
            name: "Communication Basics",
            description: "Essential communication movements",
            duration: 15.0
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
        syncAudio() // Immediately sync audio state
    }
    
    func play() {
        isPlaying = true
        syncAudio()
    }
    
    func pause() {
        isPlaying = false
        syncAudio()
    }
    
    func rewind() {
        currentTime = 0.0
        audioManager.seek(to: 0.0)
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
        // Sync audio when scrubbing
        audioManager.seek(to: currentTime)
    }
    
    // MARK: - Computed Properties
    var playbackSpeed: Double {
        return isSlowMotion ? slowMotionFactor : 1.0
    }
    
    var playbackRate: Float {
        return Float(playbackSpeed)
    }
    
    var progressPercentage: Double {
        return totalTime > 0 ? currentTime / totalTime : 0
    }
    
    // MARK: - Audio Sync
    func syncAudio() {
        audioManager.sync(to: currentTime, isPlaying: isPlaying, playbackRate: playbackRate)
    }
}
