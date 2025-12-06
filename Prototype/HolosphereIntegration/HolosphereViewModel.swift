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

@MainActor
class HolosphereViewModel: ObservableObject {
    // MARK: - Animation State
    @Published var currentFrame: Int = 0
    @Published var totalFrames: Int = 100
    @Published var isPlaying: Bool = false
    @Published var fps: Double = 30.0
    
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
    
    // MARK: - Setup
    func setup(totalFrames: Int, fps: Double = 30.0) {
        self.totalFrames = totalFrames
        self.fps = fps
        self.currentFrame = 0
        self.isLoading = false
        
        // Setup video players if files exist
        setupVideoPlayers()
    }
    
    private func setupVideoPlayers() {
        // Look for videos in Data/video
        // We assume standard names or pass them in. For now, hardcoded based on file_search.
        if let leftURL = Bundle.main.url(forResource: "camera_left", withExtension: "mov", subdirectory: "Data/video") {
            leftPlayer.replaceCurrentItem(with: AVPlayerItem(url: leftURL))
        } else {
            // Fallback to absolute path for simulator if bundle fails (common in dev)
             let path = "/Users/Patron/Documents/Code/Holosync Final/Prototype/Data/video/camera_left.mov"
             let url = URL(fileURLWithPath: path)
             leftPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
        }
        
        if let rightURL = Bundle.main.url(forResource: "camera_right", withExtension: "mov", subdirectory: "Data/video") {
            rightPlayer.replaceCurrentItem(with: AVPlayerItem(url: rightURL))
        } else {
             let path = "/Users/Patron/Documents/Code/Holosync Final/Prototype/Data/video/camera_right.mov"
             let url = URL(fileURLWithPath: path)
             rightPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
        }
        
        leftPlayer.actionAtItemEnd = .pause
        rightPlayer.actionAtItemEnd = .pause
        
        // Mute videos to avoid echo/noise
        leftPlayer.isMuted = true
        rightPlayer.isMuted = true
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
        
        // Start videos
        if videoSelection != .none {
            leftPlayer.play()
            rightPlayer.play()
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
        
        // If video is active and playing, sync to video time
        if videoSelection != .none && (leftPlayer.rate > 0 || rightPlayer.rate > 0) {
            // Use the active player's time
            let player = (videoSelection == .right) ? rightPlayer : leftPlayer
            let currentTime = player.currentTime().seconds
            let newFrame = Int(currentTime * fps)
            
            if newFrame < totalFrames {
                currentFrame = newFrame
            } else {
                // Loop
                currentFrame = 0
                seek(to: 0)
                leftPlayer.play()
                rightPlayer.play()
            }
        } else {
            // Time-based update without video
            let now = CACurrentMediaTime()
            let deltaTime = now - lastTimestamp
            
            // Accumulate time logic would be better, but for now simple delta
            // If we just add frames based on delta, we might drift or be jerky.
            // Better: track start time and calculate frame from (now - startTime).
            // But we support pausing, so we need (now - resumeTime + pausedDuration).
            
            // Simple approach for now:
            if deltaTime >= (1.0 / fps) {
                let framesToAdd = Int(deltaTime * fps)
                if currentFrame + framesToAdd < totalFrames {
                    currentFrame += framesToAdd
                    lastTimestamp = now // Reset only when we advance
                } else {
                    currentFrame = 0
                    lastTimestamp = now
                }
            }
        }
    }
}
