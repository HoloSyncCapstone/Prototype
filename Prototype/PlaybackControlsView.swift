import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    if let session = viewModel.selectedSession {
                        Text(session.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(session.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Close button
                Button {
                    Task {
                        viewModel.closeSession()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonBorderShape(.circle)
            }
            
            // Time display
            HStack {
                Text(formatTime(viewModel.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                
                Spacer()
                
                Text(formatTime(viewModel.totalTime))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            
            // Progress slider
            Slider(
                value: Binding(
                    get: { viewModel.currentTime },
                    set: { viewModel.scrubTo(time: $0) }
                ),
                in: 0...viewModel.totalTime
            )
            .tint(.blue)
            
            // Control buttons
            HStack(spacing: 20) {
                // Rewind button
                Button {
                    viewModel.rewind()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonBorderShape(.circle)
                
                // Play/Pause button
                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .frame(width: 60, height: 60)
                        .background(.blue.gradient)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .buttonBorderShape(.circle)
                
                // Slow motion toggle
                Button {
                    viewModel.toggleSlowMotion()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "slowmo")
                            .font(.title3)
                        if viewModel.isSlowMotion {
                            Text("0.25x")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(viewModel.isSlowMotion ? .blue : .primary)
                }
                .buttonBorderShape(.roundedRectangle)
            }
            
            // Speed indicator
            if viewModel.isSlowMotion {
                Label("Slow Motion Active", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1), in: Capsule())
            }
        }
        .padding(30)
        .frame(width: 400)
        .glassBackgroundEffect()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}
