import SwiftUI
import AVKit

struct HolospherePlaybackControls: View {
    @ObservedObject var viewModel: HolosphereViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Holosphere Animation")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Session Selector
                    Picker("Session", selection: $viewModel.selectedSession) {
                        ForEach(viewModel.sessions) { session in
                            Text(session.name).tag(session as HolosphereSession?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                
                Spacer()
                
                Button(action: {
                    // Just dismiss the immersive space to return to the main menu
                    Task {
                        await dismissImmersiveSpace()
                        // Re-open the main window
                        openWindow(id: "main")
                    }
                }) {
                    Label("Back", systemImage: "arrow.left.circle.fill") // Changed icon and label
                        .font(.title3)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .glassBackgroundEffect()
            }
            
            // Video Player Area
            if viewModel.showVideoPlayer {
                HStack(spacing: 20) {
                    // Always show Right Player
                    VideoPlayer(player: viewModel.rightPlayer)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(16)
                        .disabled(true) // Disable interaction (pausing via click)
                        .allowsHitTesting(false) // Ensure clicks pass through or are ignored
                }
                .frame(minHeight: 400, maxHeight: 600) // Increased height
            }
            
            Spacer()
            
            // Controls Container
            VStack(spacing: 20) { // Increased spacing
                // Scrubber
                HStack(spacing: 16) { // Increased spacing
                    Text("\(Int(viewModel.currentFrame))")
                        .font(.body) // Larger font
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    
                    Slider(value: Binding(
                        get: { Double(viewModel.currentFrame) },
                        set: { viewModel.seek(to: Int($0)) }
                    ), in: 0...Double(max(1, viewModel.totalFrames)))
                    .tint(.purple)
                    .controlSize(.large) // Larger slider
                    
                    Text("\(viewModel.totalFrames)")
                        .font(.body) // Larger font
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                
                // Playback Buttons
                HStack(spacing: 48) { // Increased spacing
                    Button(action: { viewModel.seek(to: 0) }) {
                        Image(systemName: "backward.end.fill")
                            .font(.largeTitle) // Larger icon
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72)) // Larger icon
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32) // Increased padding
            .glassBackgroundEffect()
            .frame(maxWidth: 900) // Increased width
        }
        .padding(60) // Increased padding
        .frame(width: 1200, height: viewModel.showVideoPlayer ? 900 : 500) // Significantly larger frame
        .animation(.spring, value: viewModel.showVideoPlayer)
    }
}
