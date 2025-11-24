import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 16) {
            // Header with session title
            if let session = viewModel.selectedSession {
                Text(session.name)
                    .font(.title2)
                    .bold()
                    .padding(.top, 8)
                Text(session.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Scrubber and time display
            HStack {
                Text(formatTime(viewModel.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                Slider(
                    value: $viewModel.currentTime,
                    in: 0...viewModel.totalTime
                )
                .accentColor(.blue)
                Text(formatTime(viewModel.totalTime))
                    .font(.caption)
                    .monospacedDigit()
            }
            .padding(.horizontal)

            // Playback controls
            HStack(spacing: 32) {
                Button(action: { viewModel.rewind() }) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                Button(action: { viewModel.forward() }) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .padding(.vertical)

            // Speed selector
            Picker("Speed", selection: $viewModel.playbackSpeed) {
                Text("0.5x").tag(0.5)
                Text("1x").tag(1.0)
                Text("1.5x").tag(1.5)
                Text("2x").tag(2.0)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
        .padding()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

