// SubtitleView.swift - Subtitle display component for VisionOS
import SwiftUI

struct ImmersiveSubtitleView: View {
    let text: String
    
    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 64)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.85))
                        .shadow(color: .black.opacity(0.6), radius: 16, x: 0, y: 8)
                )
                .padding()
                .frame(maxWidth: 1200, alignment: .leading)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ImmersiveSubtitleView(text: "Welcome to the hand gesture demonstration")
        ImmersiveSubtitleView(text: "Watch carefully as the hand moves through different positions")
        ImmersiveSubtitleView(text: "")
    }
    .preferredColorScheme(.dark)
}
