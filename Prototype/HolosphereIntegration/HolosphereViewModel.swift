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

struct HolosphereSession: Identifiable, Hashable {
    let id: String
    let name: String
    let headCSV: URL
    let handCSV: URL
    let handGlobalCSV: URL
    let videoURL: URL
}

@MainActor
class HolosphereViewModel: ObservableObject {
    // MARK: - Session Management
    @Published var sessions: [HolosphereSession] = []
    @Published var selectedSession: HolosphereSession? {
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
    @Published var playbackSpeed: Double = 2.2
    
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
        // Updated path: Moved to project root (parent of Prototype folder)
        let rootPath = "/Users/Patron/Documents/Code/Holosync Final/Prototype/Motion Recordings"
        
        var sessionsFound: [HolosphereSession] = []
        
        func findSessions(in directory: String) {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { return }
            
            let trackingPath = (directory as NSString).appendingPathComponent("tracking")
            let videoPath = (directory as NSString).appendingPathComponent("video")
            
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: trackingPath, isDirectory: &isDir) && isDir.boolValue {
                // Check for specific files
                let headPath = (trackingPath as NSString).appendingPathComponent("device_pose.csv")
                let handsLocalPath = (trackingPath as NSString).appendingPathComponent("hand_pose_local.csv")
                let handsWorldPath = (trackingPath as NSString).appendingPathComponent("hand_pose_world.csv")
                let videoRightPath = (videoPath as NSString).appendingPathComponent("camera_right.mov")
                
                if fileManager.fileExists(atPath: headPath) &&
                   fileManager.fileExists(atPath: handsLocalPath) &&
                   fileManager.fileExists(atPath: handsWorldPath) &&
                   fileManager.fileExists(atPath: videoRightPath) {
                    
                    let folderName = (directory as NSString).lastPathComponent
                    let parentName = (directory as NSString).deletingLastPathComponent.components(separatedBy: "/").last ?? ""
                    let name = "\(parentName) - \(folderName)"
                    
                    let session = HolosphereSession(
                        id: directory,
                        name: name,
                        headCSV: URL(fileURLWithPath: headPath),
                        handCSV: URL(fileURLWithPath: handsLocalPath),
                        handGlobalCSV: URL(fileURLWithPath: handsWorldPath),
                        videoURL: URL(fileURLWithPath: videoRightPath)
                    )
                    sessionsFound.append(session)
                    return 
                }
            }
            
            for item in contents {
                let itemPath = (directory as NSString).appendingPathComponent(item)
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) && isDir.boolValue {
                    findSessions(in: itemPath)
                }
            }
        }
        
        findSessions(in: rootPath)
        self.sessions = sessionsFound.sorted(by: { $0.name < $1.name })
        
        if selectedSession == nil, let first = sessions.first {
            selectedSession = first
        }
    }
    
    func loadSession(_ session: HolosphereSession) {
        stopPlayback()
        isLoading = true
        loadingStatus = "Loading \(session.name)..."
        loadingProgress = 0.0
        
        rightPlayer.replaceCurrentItem(with: AVPlayerItem(url: session.videoURL))
        currentFrame = 0
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
        rightPlayer.isMuted = true
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
        
        // Start videos at normal speed
        if videoSelection != .none {
            leftPlayer.rate = 1.0
            rightPlayer.rate = 1.0
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
        
        // Time-based update for animation (decoupled from video time)
        let now = CACurrentMediaTime()
        let deltaTime = now - lastTimestamp
        
        // Apply playback speed to delta time for the animation
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
                if videoSelection != .none {
                    leftPlayer.rate = 1.0
                    rightPlayer.rate = 1.0
                }
            }
        }
    }
}
