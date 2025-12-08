// AudioPlayerManager.swift - Synchronized audio playback for animations
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isLoaded: Bool = false
    @Published var duration: TimeInterval = 0.0
    
    // MARK: - WAV File Fixing
    
    /// Fix WAV file with corrupted data chunk size header
    private func fixWAVHeader(at url: URL) -> URL? {
        guard let data = try? Data(contentsOf: url) else {
            print("❌ Could not read WAV file")
            return nil
        }
        
        var mutableData = data
        
        // Find 'data' chunk
        guard let dataRange = mutableData.range(of: Data("data".utf8)) else {
            print("⚠️ No 'data' chunk found in WAV")
            return nil
        }
        
        let dataPos = dataRange.lowerBound
        print("📍 Found 'data' chunk at offset \(String(format: "0x%x", dataPos))")
        
        // Read current data chunk size (4 bytes after 'data')
        let sizeOffset = dataPos + 4
        guard sizeOffset + 4 <= mutableData.count else {
            print("❌ WAV file too short")
            return nil
        }
        
        let currentSize = mutableData[sizeOffset..<sizeOffset+4].withUnsafeBytes {
            $0.load(as: UInt32.self)
        }
        
        print("📊 Current data chunk size: \(currentSize) bytes")
        
        // Calculate actual data size
        let actualSize = UInt32(mutableData.count - dataPos - 8)
        print("📏 Actual data size: \(actualSize) bytes (\(Double(actualSize) / 1024 / 1024) MB)")
        
        if currentSize == 0 || currentSize != actualSize {
            print("🔧 Fixing data chunk size...")
            
            // Update data chunk size (little-endian)
            withUnsafeBytes(of: actualSize.littleEndian) { bytes in
                mutableData.replaceSubrange(sizeOffset..<sizeOffset+4, with: bytes)
            }
            
            // Update RIFF chunk size at offset 4 (file size - 8)
            let riffSize = UInt32(mutableData.count - 8)
            withUnsafeBytes(of: riffSize.littleEndian) { bytes in
                mutableData.replaceSubrange(4..<8, with: bytes)
            }
            
            // Create fixed file in temporary directory
            let tempDir = FileManager.default.temporaryDirectory
            let fixedURL = tempDir.appendingPathComponent("audio_fixed.wav")
            
            do {
                try mutableData.write(to: fixedURL)
                print("✅ Fixed WAV file saved to temp directory")
                return fixedURL
            } catch {
                print("❌ Failed to write fixed WAV: \(error)")
                return nil
            }
        } else {
            print("✅ WAV file header appears valid")
            return nil // No fix needed
        }
    }
    
    // MARK: - Setup
    
    /// Load audio file from URL
    func loadAudio(url: URL) {
        do {
            print("🔍 Loading audio from URL: \(url.path)")
            
            // Check file size
            let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
            print("📊 Audio file size: \(fileSize / 1024) KB")
            
            // Check if file needs header fix
            var workingURL = url
            if let fixedURL = fixWAVHeader(at: url) {
                workingURL = fixedURL
                print("🔄 Using fixed WAV file")
            }
            
            // Configure audio session for spatial audio
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: workingURL)
            audioPlayer?.prepareToPlay()
            
            if let player = audioPlayer {
                duration = player.duration
                isLoaded = true
                
                let frames = Int(player.duration * 44100) // Assuming 44.1kHz
                print("📏 Audio file: \(frames) frames at \(player.format.sampleRate) Hz")
                print("⏱️  Calculated duration: \(String(format: "%.2f", player.duration))s")
                print("✅ Audio loaded: \(url.lastPathComponent), duration: \(String(format: "%.2f", duration))s")
            }
        } catch {
            print("❌ Failed to load audio: \(error)")
            isLoaded = false
        }
    }
    
    /// Load audio file from bundle
    func loadAudio(filename: String, subdirectory: String = "Data/audio") {
        // Try multiple approaches to find the file
        var url: URL?
        
        // Method 1: With subdirectory (for folder references)
        url = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: subdirectory)
        
        // Method 2: Direct in bundle (for flat structure)
        if url == nil {
            let nameWithoutExt = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext.isEmpty ? nil : ext)
        }
        
        // Method 3: Search in all bundle resources
        if url == nil, let resourcePath = Bundle.main.resourcePath {
            let searchPath = (resourcePath as NSString).appendingPathComponent(subdirectory)
            let fullPath = (searchPath as NSString).appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fullPath) {
                url = URL(fileURLWithPath: fullPath)
            }
        }
        
        guard let fileURL = url else {
            print("⚠️ Audio file not found: \(filename)")
            print("   Searched in: \(subdirectory)")
            print("   Bundle path: \(Bundle.main.bundlePath)")
            return
        }
        
        do {
            print("🔍 Found audio at: \(fileURL.path)")
            
            // Check file size
            let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
            print("📊 Audio file size: \(fileSize / 1024) KB")
            
            // Check if file needs header fix
            var workingURL = fileURL
            if let fixedURL = fixWAVHeader(at: fileURL) {
                workingURL = fixedURL
                print("🔄 Using fixed WAV file")
            }
            
            // Configure audio session for spatial audio
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            // Try AVAudioFile first (more robust for malformed headers)
            do {
                let audioFile = try AVAudioFile(forReading: workingURL)
                let frameCount = audioFile.length
                let sampleRate = audioFile.fileFormat.sampleRate
                let calculatedDuration = Double(frameCount) / sampleRate
                
                print("📏 Audio file: \(frameCount) frames at \(sampleRate) Hz")
                print("⏱️  Calculated duration: \(String(format: "%.2f", calculatedDuration))s")
                
                // Now try to create player with this validated file
                audioPlayer = try AVAudioPlayer(contentsOf: workingURL)
                audioPlayer?.prepareToPlay()
                audioPlayer?.volume = 1.0
                audioPlayer?.enableRate = true
                
                // Use calculated duration if player duration is 0
                let playerDuration = audioPlayer?.duration ?? 0
                duration = playerDuration > 0 ? playerDuration : calculatedDuration
                isLoaded = true
                
                print("✅ Audio loaded: \(filename), duration: \(String(format: "%.2f", duration))s")
                
            } catch {
                print("⚠️ AVAudioFile failed, trying direct AVAudioPlayer: \(error)")
                
                // Fall back to regular loading
                audioPlayer = try AVAudioPlayer(contentsOf: workingURL)
                audioPlayer?.prepareToPlay()
                audioPlayer?.volume = 1.0
                audioPlayer?.enableRate = true
                
                duration = audioPlayer?.duration ?? 0
                isLoaded = duration > 0
                
                if isLoaded {
                    print("✅ Audio loaded: \(filename), duration: \(String(format: "%.2f", duration))s")
                } else {
                    print("⚠️ Audio player created but duration is 0")
                    print("   This WAV file may have a corrupted header - attempting auto-fix failed")
                }
            }
        } catch {
            print("❌ Failed to load audio: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Playback Control
    
    /// Start or resume playback
    func play() {
        guard isLoaded else { return }
        audioPlayer?.play()
    }
    
    /// Pause playback
    func pause() {
        audioPlayer?.pause()
    }
    
    /// Stop playback and reset to beginning
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
    }
    
    /// Seek to specific time (for scrubbing)
    func seek(to time: TimeInterval) {
        guard isLoaded, let player = audioPlayer else { return }
        
        // Clamp time to valid range
        let clampedTime = max(0, min(time, duration))
        
        let wasPlaying = player.isPlaying
        player.currentTime = clampedTime
        
        // Resume playing if it was playing before
        if wasPlaying {
            player.play()
        }
    }
    
    /// Get current playback time
    var currentTime: TimeInterval {
        return audioPlayer?.currentTime ?? 0.0
    }
    
    /// Check if audio is currently playing
    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    /// Set playback rate (for slow motion)
    func setRate(_ rate: Float) {
        guard isLoaded else { return }
        audioPlayer?.enableRate = true
        audioPlayer?.rate = rate
    }
    
    // MARK: - Sync Methods
    
    /// Synchronize audio with animation time
    func sync(to time: TimeInterval, isPlaying: Bool, playbackRate: Float = 1.0) {
        guard isLoaded else { return }
        
        // Check if we need to seek (if difference is more than 0.1 seconds)
        let timeDifference = abs(currentTime - time)
        if timeDifference > 0.1 {
            seek(to: time)
        }
        
        // Update playback state
        setRate(playbackRate)
        
        if isPlaying && !self.isPlaying {
            play()
        } else if !isPlaying && self.isPlaying {
            pause()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
