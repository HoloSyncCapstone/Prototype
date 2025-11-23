// VideoPlayerView.swift - Video player with audio and subtitles
import SwiftUI
import AVFoundation
import Combine

struct VideoPlayerView: View {
    @EnvironmentObject var viewModel: ViewModel
    @StateObject private var playerViewModel = VideoPlayerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Video display (optional - can hide if only audio needed)
            if playerViewModel.showVideo {
                VideoPlayerLayer(player: playerViewModel.player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
            }
            
            // Subtitle display
            SubtitleView(currentSubtitle: playerViewModel.currentSubtitle)
                .frame(height: 120)
                .padding(.horizontal)
            
            // Playback controls
            VStack(spacing: 16) {
                // Progress bar
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { playerViewModel.currentTime },
                            set: { playerViewModel.seek(to: $0) }
                        ),
                        in: 0...playerViewModel.duration
                    )
                    .tint(.blue)
                    
                    HStack {
                        Text(formatTime(playerViewModel.currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(playerViewModel.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Control buttons
                HStack(spacing: 30) {
                    // Rewind 10s
                    Button(action: { playerViewModel.skip(by: -10) }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                    }
                    
                    // Play/Pause
                    Button(action: { playerViewModel.togglePlayPause() }) {
                        Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                    }
                    
                    // Forward 10s
                    Button(action: { playerViewModel.skip(by: 10) }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                    }
                }
                
                // Additional controls
                HStack(spacing: 20) {
                    // Toggle video visibility
                    Button(action: { playerViewModel.showVideo.toggle() }) {
                        Label(
                            playerViewModel.showVideo ? "Hide Video" : "Show Video",
                            systemImage: playerViewModel.showVideo ? "video.slash" : "video"
                        )
                        .font(.caption)
                    }
                    
                    Spacer()
                    
                    // Volume control
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .font(.caption)
                        Slider(
                            value: Binding(
                                get: { playerViewModel.volume },
                                set: { playerViewModel.setVolume($0) }
                            ),
                            in: 0...1
                        )
                        .frame(width: 100)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            playerViewModel.setupPlayer(
                videoURL: getVideoURL(),
                subtitles: loadSubtitles()
            )
            
            // Sync with main ViewModel
            playerViewModel.onTimeUpdate = { time in
                viewModel.currentTime = time
            }
        }
        .onDisappear {
            playerViewModel.cleanup()
        }
    }
    
    private func getVideoURL() -> URL? {
        // First try bundle resources
        if let url = Bundle.main.url(forResource: "camera_sbs", withExtension: "mov", subdirectory: "Data/video") {
            print("✅ Found video in bundle: \(url.path)")
            return url
        }
        if let url = Bundle.main.url(forResource: "camera_left", withExtension: "mov", subdirectory: "Data/video") {
            print("✅ Found video in bundle: \(url.path)")
            return url
        }
        
        // Fallback: Try direct file path (for development)
        let fileManager = FileManager.default
        let possiblePaths = [
            "/Users/Patron/Documents/Prototype/Prototype/Data/video/camera_sbs.mov",
            "/Users/Patron/Documents/Prototype/Prototype/Data/video/camera_left.mov",
            "/Users/Patron/Documents/Prototype/Prototype/Data/video/camera_right.mov"
        ]
        
        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                print("✅ Found video at path: \(path)")
                return url
            }
        }
        
        print("❌ No video file found in bundle or at direct paths")
        return nil
    }
    
    private func loadSubtitles() -> [SubtitleEntry] {
        // First try bundle resources
        if let subtitles = try? SubtitleLoader.loadFromJSON(filename: "timecoded_transcript") {
            print("✅ Loaded \(subtitles.count) subtitles from bundle")
            return subtitles
        }
        
        // Fallback: Try direct file path
        let directPath = "/Users/Patron/Documents/Prototype/Prototype/Data/transcripts/timecoded_transcript.json"
        if FileManager.default.fileExists(atPath: directPath) {
            do {
                let url = URL(fileURLWithPath: directPath)
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let subtitles = try decoder.decode([SubtitleEntry].self, from: data)
                print("✅ Loaded \(subtitles.count) subtitles from direct path")
                return subtitles.sorted { $0.startTime < $1.startTime }
            } catch {
                print("❌ Failed to load subtitles from path: \(error)")
            }
        }
        
        // Fallback to sample subtitles
        print("⚠️ Using sample subtitles")
        return SubtitleLoader.createSampleSubtitles()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Subtitle Display View
struct SubtitleView: View {
    let currentSubtitle: String?
    
    var body: some View {
        ZStack {
            if let subtitle = currentSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.75))
                    )
                    .transition(.opacity)
            } else {
                Text("No subtitles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: currentSubtitle)
    }
}

// MARK: - Video Player Layer (UIKit wrapper)
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        context.coordinator.playerLayer = playerLayer
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

// MARK: - Video Player ViewModel
class VideoPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentSubtitle: String?
    @Published var volume: Float = 1.0
    @Published var showVideo = true // Show video by default
    
    var player: AVPlayer = AVPlayer()
    private var timeObserver: Any?
    private var subtitles: [SubtitleEntry] = []
    
    var onTimeUpdate: ((TimeInterval) -> Void)?
    
    func setupPlayer(videoURL: URL?, subtitles: [SubtitleEntry]) {
        guard let url = videoURL else {
            print("⚠️ No video URL provided")
            return
        }
        
        self.subtitles = subtitles
        
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.volume = volume
        
        // Get duration
        Task { @MainActor in
            if let duration = try? await playerItem.asset.load(.duration) {
                self.duration = CMTimeGetSeconds(duration)
            }
        }
        
        // Add time observer for progress updates
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentTime = CMTimeGetSeconds(time)
            self.currentTime = currentTime
            self.updateSubtitle(for: currentTime)
            self.onTimeUpdate?(currentTime)
        }
        
        print("✅ Video player setup complete. Duration: \(duration)s, Subtitles: \(subtitles.count)")
    }
    
    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
    }
    
    func skip(by seconds: TimeInterval) {
        let newTime = max(0, min(duration, currentTime + seconds))
        seek(to: newTime)
    }
    
    func setVolume(_ volume: Float) {
        self.volume = volume
        player.volume = volume
    }
    
    private func updateSubtitle(for time: TimeInterval) {
        let activeSubtitle = subtitles.first { $0.contains(time: time) }
        currentSubtitle = activeSubtitle?.text
    }
    
    func cleanup() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        player.pause()
    }
}
