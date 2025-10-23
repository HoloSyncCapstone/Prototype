import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var selectedSpeed: Double = 1.0
    
    var body: some View {
        VStack(spacing: 28) {
            // Header with exit button
            HStack {
                VStack(alignment: .center, spacing: 6) {
                    if let session = viewModel.selectedSession {
                        Text(session.name)
                            .font(.system(size: 34, weight: .semibold))
                            .multilineTextAlignment(.center)
                        Text(session.description)
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 520)
                    }
                }
                Spacer()

                // Exit to menu button (keeps original behavior)
                Button {
                    Task {
                        await exitToMenu()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Exit")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(.primary)
                }
                .buttonBorderShape(.capsule)
                .frame(minWidth: 88)
            }
            .padding(.horizontal, 8)

            // Time display
            HStack {
                Text(formatTime(viewModel.currentTime))
                    .font(.system(size: 20, weight: .medium))
                    .monospacedDigit()

                Spacer()

                Text(formatTime(viewModel.totalTime))
                    .font(.system(size: 20, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            // Progress slider (styled)
            Slider(
                value: Binding(
                    get: { viewModel.currentTime },
                    set: { viewModel.scrubTo(time: $0) }
                ),
                in: 0...max(0.0001, viewModel.totalTime)
            )
            .tint(.purple)
            .frame(height: 22)
            .padding(.horizontal, 6)

            // Control buttons (centered, purple style)
            HStack(spacing: 36) {
                // Rewind button (circular, subtle glass)
                Button {
                    viewModel.rewind()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24, weight: .medium))
                        .frame(width: 66, height: 66)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(.primary)
                }
                .buttonBorderShape(.circle)

                // Play/Pause large circular gradient button
                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .frame(width: 98, height: 98)
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.95), Color.blue.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(color: Color.purple.opacity(0.25), radius: 12, x: 0, y: 6)
                        .foregroundStyle(.white)
                }
                .buttonBorderShape(.circle)

                // Forward button
                Button {
                    viewModel.rewind() // keep as placeholder if there's a forward method use it instead
                    // If ViewModel has a forward function, replace above line with viewModel.forward()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 24, weight: .medium))
                        .frame(width: 66, height: 66)
                        .background(.ultraThinMaterial, in: Circle())
                        .foregroundStyle(.primary)
                }
                .buttonBorderShape(.circle)
            }
            .padding(.top, 6)

            // Speed dropdown
            HStack {
                Spacer()
                Menu {
                    Button("0.25x") { changeSpeed(0.25) }
                    Button("0.5x")  { changeSpeed(0.5) }
                    Button("1x")    { changeSpeed(1.0) }
                    Button("1.5x")  { changeSpeed(1.5) }
                    Button("2x")    { changeSpeed(2.0) }
                } label: {
                    HStack(spacing: 8) {
                        Text("Speed: \(speedLabel(selectedSpeed))")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .menuStyle(BorderlessButtonMenuStyle())
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(width: 720)
        .background(
            LinearGradient(
                colors: [Color("MenuTop").opacity(0.95), Color("MenuBottom").opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 8)
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

    private func speedLabel(_ speed: Double) -> String {
        if speed == floor(speed) { return String(format: "%.0fx", speed) }
        return String(format: "%.2gx", speed)
    }

    private func changeSpeed(_ speed: Double) {
        selectedSpeed = speed
        // Post a notification so ViewModel (or other part of the app) can apply the change.
        NotificationCenter.default.post(name: .playbackRateChanged, object: nil, userInfo: ["rate": speed])
        // If your ViewModel exposes an API to set playback rate, you can also call it here:
        // viewModel.setPlaybackRate?(speed) // uncomment if method exists
    }
}

// Notification name extension (safe, non-breaking)
extension Notification.Name {
    static let playbackRateChanged = Notification.Name("PlaybackRateChanged")
}

