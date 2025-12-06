//
//  HolosphereViewModel.swift
//  Prototype
//
//  Created for Holosphere Integration
//

import SwiftUI
import RealityKit
import Combine

//
//  HolosphereViewModel.swift
//  Prototype
//
//  Created for Holosphere Integration
//

import SwiftUI
import RealityKit
import Combine
import AVFoundation

enum VideoSelection: String, CaseIterable, Identifiable {
    case left = "Left"
    case right = "Right"
    case both = "Both"
    case none = "None"
    
    var id: String { self.rawValue }
}

struct MotionSession: Identifiable, Hashable {
    let id: String
    let name: String
    let headCSV: URL
    let handCSV: URL
    let handGlobalCSV: URL
    let videoURL: URL
    let transcriptURL: URL?
}

@MainActor
class MotionReplayViewModel: ObservableObject {
    // MARK: - Session Management
    @Published var sessions: [MotionSession] = []
    @Published var selectedSession: MotionSession? {
        didSet {
            if let session = selectedSession, oldValue != session {
                loadSession(session)
            }
        }
    }
    
    // MARK: - Animation State
    @Published var currentFrame: Int = 0
    @Published var totalFrames: Int = 100
    @Published var isPlaying: Bool = false
    @Published var fps: Double = 30.0
    @Published var playbackSpeed: Double = 1.0
    
    // MARK: - Subtitles
    @Published var subtitles: [SubtitleEntry] = []
    @Published var currentSubtitle: String = ""
    @Published var showSubtitles: Bool = false
    
    // MARK: - Loading State
    @Published var isLoading: Bool = true
    @Published var loadingProgress: Double = 0.0
    @Published var loadingStatus: String = "Initializing..."
    
    // MARK: - Video State
    // Default to right video, always visible
    @Published var videoSelection: VideoSelection = .right {
        didSet {
            updateVideoVisibility()
        }
    }
    @Published var showVideoPlayer: Bool = true
    
    // AVPlayers
    let leftPlayer = AVPlayer()
    let rightPlayer = AVPlayer()
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: TimeInterval = 0
    
    init() {
        scanForSessions()
    }
    
    // MARK: - Session Logic
    func scanForSessions() {
        let fileManager = FileManager.default
        
        print("🔍 --- DEBUG: Scanning for Data Session ---")
        
        // Dynamic path resolution for "Data" folder
        var dataPath: String?
        
        // 1. Try App Bundle (for deployed app)
        if let bundlePath = Bundle.main.path(forResource: "Data", ofType: nil) {
            dataPath = bundlePath
            print("✅ Found Data folder in Bundle: \(bundlePath)")
        } else {
            print("⚠️ 'Data' folder not found via Bundle.main.path(forResource:...)")
        }
        
        // 2. Try Source Directory (for Debugging in Simulator/Xcode)
        if dataPath == nil {
            // #file is .../Prototype/Prototype/HolosphereIntegration/HolosphereViewModel.swift
            let currentFileURL = URL(fileURLWithPath: #file)
            let integrationDir = currentFileURL.deletingLastPathComponent() // .../HolosphereIntegration
            let innerPrototypeDir = integrationDir.deletingLastPathComponent() // .../Prototype (inner)
            let outerPrototypeDir = innerPrototypeDir.deletingLastPathComponent() // .../Prototype (outer)
            
            // Check inner Prototype/Data
            let path1 = innerPrototypeDir.appendingPathComponent("Data").path
            // Check outer Prototype/Data
            let path2 = outerPrototypeDir.appendingPathComponent("Data").path
            
            if fileManager.fileExists(atPath: path1) {
                dataPath = path1
                print("📂 Found Data in Inner Source: \(path1)")
            } else if fileManager.fileExists(atPath: path2) {
                dataPath = path2
                print("📂 Found Data in Outer Source: \(path2)")
            } else {
                print("❌ Could not find Data folder in Bundle or Source paths.")
            }
        }
        
        guard let directory = dataPath else { return }
        
        // Construct paths for the single session in Data
        let trackingPath = (directory as NSString).appendingPathComponent("tracking")
        let videoPath = (directory as NSString).appendingPathComponent("video")
        let transcriptsPath = (directory as NSString).appendingPathComponent("transcripts")
        
        let headPath = (trackingPath as NSString).appendingPathComponent("device_pose.csv")
        let handsLocalPath = (trackingPath as NSString).appendingPathComponent("hand_pose_local.csv")
        let handsWorldPath = (trackingPath as NSString).appendingPathComponent("hand_pose_world.csv")
        let videoRightPath = (videoPath as NSString).appendingPathComponent("camera_right.mov")
        let transcriptPath = (transcriptsPath as NSString).appendingPathComponent("timecoded_transcript.json")
        
        // Verify essential files exist
        if fileManager.fileExists(atPath: headPath) &&
           fileManager.fileExists(atPath: handsLocalPath) &&
           fileManager.fileExists(atPath: handsWorldPath) &&
           fileManager.fileExists(atPath: videoRightPath) {
            
            let transcriptURL = fileManager.fileExists(atPath: transcriptPath) ? URL(fileURLWithPath: transcriptPath) : nil
            
            let session = MotionSession(
                id: directory,
                name: "Default Session (Data)",
                headCSV: URL(fileURLWithPath: headPath),
                handCSV: URL(fileURLWithPath: handsLocalPath),
                handGlobalCSV: URL(fileURLWithPath: handsWorldPath),
                videoURL: URL(fileURLWithPath: videoRightPath),
                transcriptURL: transcriptURL
            )
            
            print("✅ Created session from Data folder")
            
            DispatchQueue.main.async {
                self.sessions = [session]
                self.selectedSession = session // Auto-select
            }
        } else {
            print("❌ Missing required files in Data folder:")
            if !fileManager.fileExists(atPath: headPath) { print("   - Missing: device_pose.csv") }
            if !fileManager.fileExists(atPath: handsLocalPath) { print("   - Missing: hand_pose_local.csv") }
            if !fileManager.fileExists(atPath: handsWorldPath) { print("   - Missing: hand_pose_world.csv") }
            if !fileManager.fileExists(atPath: videoRightPath) { print("   - Missing: camera_right.mov") }
        }
    }
    
    func loadSession(_ session: MotionSession) {
        stopPlayback()
        isLoading = true
        loadingStatus = "Loading \(session.name)..."
        loadingProgress = 0.0
        
        rightPlayer.replaceCurrentItem(with: AVPlayerItem(url: session.videoURL))
        currentFrame = 0
        
        // Load subtitles
        subtitles = []
        currentSubtitle = ""
        if let url = session.transcriptURL {
            do {
                subtitles = try SubtitleLoader.loadFromURL(url)
                print("✅ Loaded \(subtitles.count) subtitles")
            } catch {
                print("⚠️ Failed to load subtitles: \(error)")
            }
        }
    }
    
    // MARK: - Setup
    func setup(totalFrames: Int, fps: Double = 30.0) {
        self.totalFrames = totalFrames
        self.currentFrame = 0
        self.isLoading = false
        
        // Attempt to calculate FPS from video duration for better sync
        if let item = rightPlayer.currentItem {
            Task {
                do {
                    let duration = try await item.asset.load(.duration).seconds
                    if duration > 0 {
                        let calculatedFPS = Double(totalFrames) / duration
                        print("🎥 Video Duration: \(duration)s, Total Frames: \(totalFrames)")
                        print("🔄 Recalculated FPS: \(calculatedFPS) (was \(fps))")
                        
                        await MainActor.run {
                            self.fps = calculatedFPS
                        }
                    } else {
                        self.fps = fps
                    }
                } catch {
                    print("⚠️ Failed to load video duration: \(error)")
                    self.fps = fps
                }
            }
        } else {
            self.fps = fps
        }
        
        leftPlayer.actionAtItemEnd = .pause
        rightPlayer.actionAtItemEnd = .pause
        leftPlayer.isMuted = true
        rightPlayer.isMuted = false // Enable audio for the right player (main view)
        
        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }
    }
    
    private func setupVideoPlayers() {
        // Deprecated
    }
    
    private func updateVideoVisibility() {
        showVideoPlayer = videoSelection != .none
    }
    
    // MARK: - Playback Control
    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }
    
    func seek(to frame: Int) {
        currentFrame = min(max(0, frame), totalFrames)
        let time = Double(currentFrame) / fps
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        leftPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        rightPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func startPlayback() {
        lastTimestamp = CACurrentMediaTime()
        
        // Start videos at selected playback speed
        if videoSelection != .none {
            leftPlayer.rate = Float(playbackSpeed)
            rightPlayer.rate = Float(playbackSpeed)
        }
        
        // Start DisplayLink
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(updateLoop))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopPlayback() {
        leftPlayer.pause()
        rightPlayer.pause()
        stopDisplayLink()
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateLoop() {
        guard isPlaying else { return }
        
        if videoSelection != .none {
            // Sync animation to video time
            let videoTime = rightPlayer.currentTime().seconds
            let newFrame = Int(videoTime * fps)
            
            if newFrame != currentFrame {
                currentFrame = newFrame
            }
            
            // Check for end/loop
            if currentFrame >= totalFrames {
                currentFrame = 0
                seek(to: 0)
                if videoSelection != .none {
                    leftPlayer.rate = Float(playbackSpeed)
                    rightPlayer.rate = Float(playbackSpeed)
                }
            }
        } else {
            // Time-based update for animation (no video)
            let now = CACurrentMediaTime()
            let deltaTime = now - lastTimestamp
            
            // Apply playback speed to delta time
            let adjustedDelta = deltaTime * playbackSpeed
            
            if adjustedDelta >= (1.0 / fps) {
                let framesToAdd = Int(adjustedDelta * fps)
                if currentFrame + framesToAdd < totalFrames {
                    currentFrame += framesToAdd
                    lastTimestamp = now // Reset only when we advance
                } else {
                    // Loop
                    currentFrame = 0
                    lastTimestamp = now
                    seek(to: 0)
                }
            }
        }
        
        // Update subtitles
        if showSubtitles {
            let currentTime = Double(currentFrame) / fps
            if let entry = subtitles.first(where: { $0.contains(time: currentTime) }) {
                if currentSubtitle != entry.text {
                    currentSubtitle = entry.text
                }
            } else {
                if !currentSubtitle.isEmpty {
                    currentSubtitle = ""
                }
            }
        }
    }
}
