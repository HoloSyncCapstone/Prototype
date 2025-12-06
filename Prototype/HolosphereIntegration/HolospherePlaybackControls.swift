import SwiftUI
import AVKit

struct HolospherePlaybackControls: View {
    @ObservedObject var viewModel: HolosphereViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Holosphere Animation")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("IK & CSV Playback")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Video Toggle Removed - Always showing Right Video
                
                Spacer()
                
                Button(action: {
                    Task {
                        await dismissImmersiveSpace()
                    }
                }) {
                    Label("Exit", systemImage: "xmark.circle.fill")
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
                        .cornerRadius(12)
                }
                .frame(maxHeight: 300)
            }
            
            Spacer()
            
            // Controls Container
            VStack(spacing: 16) {
                // Scrubber
                HStack(spacing: 12) {
                    Text("\(Int(viewModel.currentFrame))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    
                    Slider(value: Binding(
                        get: { Double(viewModel.currentFrame) },
                        set: { viewModel.seek(to: Int($0)) }
                    ), in: 0...Double(max(1, viewModel.totalFrames)))
                    .tint(.purple)
                    
                    Text("\(viewModel.totalFrames)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                
                // Playback Buttons
                HStack(spacing: 32) {
                    Button(action: { viewModel.seek(to: 0) }) {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 54))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .glassBackgroundEffect()
            .frame(maxWidth: 600)
        }
        .padding(40)
        .frame(width: 800, height: viewModel.showVideoPlayer ? 600 : 400)
        .animation(.spring, value: viewModel.showVideoPlayer)
    }
}
