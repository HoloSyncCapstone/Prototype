import SwiftUI

/// A view that displays a list of key moments, allowing the user to jump to specific times in a session.
struct KeyMomentsView: View {
    let keyMoments: [KeyMoment]
    @Binding var currentTime: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KEY MOMENTS")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ForEach(keyMoments) { moment in
                Button(action: {
                    currentTime = moment.time
                }) {
                    HStack {
                        Image(systemName: moment.type.systemImage)
                            .foregroundColor(moment.type.color)
                        
                        VStack(alignment: .leading) {
                            Text(moment.title).bold()
                            Text(moment.description).font(.caption)
                        }
                        
                        Spacer()
                        
                        Text(formatTime(moment.time))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .padding()
                    .background(moment.type.color.opacity(0.2))
                    .cornerRadius(12)
                }
                .foregroundColor(.primary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Formats a time interval into a "mm:ss" string.
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
