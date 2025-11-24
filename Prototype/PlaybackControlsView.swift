import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    Task {
                        await dismissImmersiveSpace()
                    }
                }) {
                    Label("Back", systemImage: "chevron.backward")
                }
                .padding()
                Spacer()
            }
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
                // Custom scrubber: light gray background with blue progress and draggable thumb
                Scrubber(time: $viewModel.currentTime, totalTime: viewModel.totalTime)
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
            HStack {
                ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { speed in
                    Button(action: { viewModel.playbackSpeed = speed }) {
                        Text("\(speed, specifier: "%.1fx")")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(viewModel.playbackSpeed == speed ? Color.white.opacity(0.2) : Color.clear)
                            )
                    }
                }
            }
            .background(Color.black.opacity(0.2), in: Capsule())
            .padding(.horizontal)
        }
        .padding()
        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Custom scrubber control replicating iOS-style background and draggable thumb
struct Scrubber: View {
    @Binding var time: TimeInterval
    var totalTime: TimeInterval

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = totalTime > 0 ? CGFloat(time / totalTime) : 0

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 6)

                // Filled progress track
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(6, width * progress), height: 6)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
                    .offset(x: max(0, min(width - 20, width * progress - 10)))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x
                                let pct = min(max(0, x / width), 1)
                                time = TimeInterval(pct) * totalTime
                            }
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = value.location.x
                        let pct = min(max(0, x / width), 1)
                        time = TimeInterval(pct) * totalTime
                    }
            )
        }
        .frame(height: 30)
    }
}

