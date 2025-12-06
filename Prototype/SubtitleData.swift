// SubtitleData.swift - Subtitle data structures and loader
import Foundation

// MARK: - Transcript Token (word-level timing)
struct TranscriptToken: Codable {
    let text: String
    let startSec: TimeInterval
    let endSec: TimeInterval
}

// MARK: - Transcript Segment (phrase/sentence)
struct TranscriptSegment: Codable {
    let text: String
    let tokens: [TranscriptToken]
    let isFinal: Bool
}

// MARK: - Subtitle Entry
struct SubtitleEntry: Codable, Identifiable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    
    init(id: UUID = UUID(), startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
    
    func contains(time: TimeInterval) -> Bool {
        return time >= startTime && time <= endTime
    }
}

// MARK: - Subtitle Loader
class SubtitleLoader {
    
    /// Load subtitles from a specific URL
    static func loadFromURL(_ url: URL) throws -> [SubtitleEntry] {
        print("🔍 Loading subtitles from: \(url.path)")
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        // Try to decode as TranscriptSegment array (new format)
        if let segments = try? decoder.decode([TranscriptSegment].self, from: data) {
            return convertSegmentsToSubtitles(segments)
        }
        
        // Fall back to direct SubtitleEntry decoding (old format)
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let entries = try decoder.decode([SubtitleEntry].self, from: data)
        return entries.sorted { $0.startTime < $1.startTime }
    }

    /// Load subtitles from timecoded JSON file with token-based timing
    static func loadFromJSON(filename: String) throws -> [SubtitleEntry] {
        // Try multiple approaches to find the file
        var url: URL?
        
        // Method 1: With subdirectory (for folder references)
        url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Data/transcripts")
        
        // Method 2: Direct in bundle (for flat structure)
        if url == nil {
            url = Bundle.main.url(forResource: filename, withExtension: "json")
        }
        
        // Method 3: Search in all bundle resources
        if url == nil, let resourcePath = Bundle.main.resourcePath {
            let searchPath = (resourcePath as NSString).appendingPathComponent("Data/transcripts")
            let fullPath = (searchPath as NSString).appendingPathComponent("\(filename).json")
            if FileManager.default.fileExists(atPath: fullPath) {
                url = URL(fileURLWithPath: fullPath)
            }
        }
        
        guard let fileURL = url else {
            print("⚠️ Subtitle file not found: \(filename).json")
            print("   Searched in: Data/transcripts")
            print("   Bundle path: \(Bundle.main.bundlePath)")
            throw SubtitleError.fileNotFound
        }
        
        print("🔍 Found subtitles at: \(fileURL.path)")
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        
        // Try to decode as TranscriptSegment array (new format)
        if let segments = try? decoder.decode([TranscriptSegment].self, from: data) {
            return convertSegmentsToSubtitles(segments)
        }
        
        // Fall back to direct SubtitleEntry decoding (old format)
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let entries = try decoder.decode([SubtitleEntry].self, from: data)
        return entries.sorted { $0.startTime < $1.startTime }
    }
    
    /// Convert transcript segments with tokens to subtitle entries
    private static func convertSegmentsToSubtitles(_ segments: [TranscriptSegment]) -> [SubtitleEntry] {
        var subtitles: [SubtitleEntry] = []
        
        for segment in segments where !segment.tokens.isEmpty {
            let startTime = segment.tokens.first?.startSec ?? 0
            let endTime = segment.tokens.last?.endSec ?? startTime
            let text = segment.text.trimmingCharacters(in: .whitespaces)
            
            if !text.isEmpty {
                subtitles.append(SubtitleEntry(
                    startTime: startTime,
                    endTime: endTime,
                    text: text
                ))
            }
        }
        
        return subtitles.sorted { $0.startTime < $1.startTime }
    }
    
    /// Load subtitles from SRT format
    static func loadFromSRT(filename: String) throws -> [SubtitleEntry] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "srt", subdirectory: "Data/transcripts") else {
            throw SubtitleError.fileNotFound
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseSRT(content: content)
    }
    
    /// Parse SRT format content
    private static func parseSRT(content: String) -> [SubtitleEntry] {
        var subtitles: [SubtitleEntry] = []
        let blocks = content.components(separatedBy: "\n\n")
        
        for block in blocks {
            let lines = block.components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }
            
            // Parse timestamp line (format: 00:00:01,000 --> 00:00:04,000)
            let timestampLine = lines[1]
            let timestamps = timestampLine.components(separatedBy: " --> ")
            guard timestamps.count == 2 else { continue }
            
            let startTime = parseTimestamp(timestamps[0])
            let endTime = parseTimestamp(timestamps[1])
            let text = lines[2...].joined(separator: "\n")
            
            subtitles.append(SubtitleEntry(startTime: startTime, endTime: endTime, text: text))
        }
        
        return subtitles
    }
    
    /// Parse SRT timestamp format (HH:MM:SS,mmm)
    private static func parseTimestamp(_ timestamp: String) -> TimeInterval {
        let components = timestamp.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")
        guard components.count == 3 else { return 0 }
        
        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    /// Create sample subtitles for testing
    static func createSampleSubtitles() -> [SubtitleEntry] {
        return [
            SubtitleEntry(startTime: 0.0, endTime: 3.0, text: "Welcome to the demonstration"),
            SubtitleEntry(startTime: 3.5, endTime: 6.0, text: "Watch the hand gestures carefully"),
            SubtitleEntry(startTime: 6.5, endTime: 10.0, text: "This shows the skeleton tracking"),
            SubtitleEntry(startTime: 10.5, endTime: 14.0, text: "Notice the smooth animations"),
            SubtitleEntry(startTime: 14.5, endTime: 18.0, text: "End of demonstration")
        ]
    }
}

// MARK: - Errors
enum SubtitleError: Error {
    case fileNotFound
    case invalidFormat
    case decodingError
}
