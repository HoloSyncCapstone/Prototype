import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    var body: some View {
        VStack(spacing: 24) {
            // Header with exit button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let session = viewModel.selectedSession {
                        Text(session.name)
                            .font(.system(size: 28, weight: .semibold))
                        Text(session.description)
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Exit to menu button
                Button {
                    Task {
                        await exitToMenu()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                        Text("Exit")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.blue.gradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonBorderShape(.capsule)
            }
            
            // Time display
            HStack {
                Text(formatTime(viewModel.currentTime))
                    .font(.system(size: 18, weight: .medium))
                    .monospacedDigit()
                
                Spacer()
                
                Text(formatTime(viewModel.totalTime))
                    .font(.system(size: 18, weight: .medium))
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
            HStack(spacing: 28) {
                // Rewind button
                Button {
                    viewModel.rewind()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 32))
                }
                .buttonBorderShape(.circle)
                
                // Play/Pause button
                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 42))
                        .frame(width: 80, height: 80)
                        .background(.blue.gradient)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .buttonBorderShape(.circle)
                
                // Slow motion toggle
                Button {
                    viewModel.toggleSlowMotion()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "slowmo")
                            .font(.system(size: 28))
                        if viewModel.isSlowMotion {
                            Text("0.25x")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(viewModel.isSlowMotion ? .blue : .primary)
                }
                .buttonBorderShape(.roundedRectangle)
            }
            
            // Speed indicator
            if viewModel.isSlowMotion {
                Label("Slow Motion Active", systemImage: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.blue.opacity(0.1), in: Capsule())
            }
        }
        .padding(40)
        .frame(width: 550)
        .glassBackgroundEffect()
    }
    
    private func exitToMenu() async {
        // Directly dismiss the immersive space
        await dismissImmersiveSpace()
        // Close the session
        viewModel.closeSession()
        // Reopen the main window
        openWindow(id: "main")
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}
