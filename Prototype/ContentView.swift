import SwiftUI
import RealityKit

struct ContentView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var isShowingImmersiveSpace = false
    @State private var immersiveSpaceState: ImmersiveSpaceState = .closed
    
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.6),
                    Color(red: 0.3, green: 0.2, blue: 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header Card
                    VStack(spacing: 12) {
                        Text("Holos Replay Engine")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Experience expert knowledge through volumetric motion capture and immersive 3D replay")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    // Training Sessions Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20)
                    ], spacing: 20) {
                        ForEach(viewModel.trainingSessions) { session in
                            EnhancedSessionCard(
                                session: session,
                                isDisabled: immersiveSpaceState == .inTransition
                            ) {
                                Task {
                                    await selectSession(session)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    
                    // Status indicator
                    if immersiveSpaceState != .closed {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                            Text(immersiveSpaceState == .inTransition ? "Opening immersive space..." : "Immersive space is open")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedSession) { oldValue, newValue in
            Task {
                if newValue != nil && oldValue == nil {
                    // Session was selected, open immersive space
                    await openSpace()
                } else if newValue == nil && oldValue != nil {
                    // Session was closed, dismiss immersive space
                    await closeSpace()
                }
            }
        }
    }
    
    private func selectSession(_ session: TrainingSession) async {
        guard immersiveSpaceState == .closed else { return }
        viewModel.selectSession(session)
    }
    
    private func openSpace() async {
        guard immersiveSpaceState == .closed else { return }
        
        immersiveSpaceState = .inTransition
        
        let result = await openImmersiveSpace(id: "TrainingSpace")
        switch result {
        case .opened:
            immersiveSpaceState = .open
            isShowingImmersiveSpace = true
            // Dismiss this window after immersive space opens
            dismissWindow(id: "main")
        case .error:
            immersiveSpaceState = .closed
            viewModel.closeSession()
            print("Failed to open immersive space")
        case .userCancelled:
            immersiveSpaceState = .closed
            viewModel.closeSession()
            print("User cancelled opening immersive space")
        @unknown default:
            immersiveSpaceState = .closed
            viewModel.closeSession()
        }
    }
    
    private func closeSpace() async {
        // Remove the guard to always attempt to close
        immersiveSpaceState = .inTransition
        
        await dismissImmersiveSpace()
        immersiveSpaceState = .closed
        isShowingImmersiveSpace = false
    }
}

// MARK: - Enhanced Session Card Component
struct EnhancedSessionCard: View {
    let session: TrainingSession
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Icon
                Text(session.icon)
                    .font(.system(size: 50))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(session.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Description
                    Text(session.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 45)
                    
                    // Instructor
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 12))
                        Text(session.instructor)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 4)
                    
                    // Duration
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                        Text(formatDuration(session.duration))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    
                    // Accuracy Rate
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12))
                        Text("\(session.accuracyRate)% accuracy rate")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    
                    // Difficulty and Category badges
                    HStack {
                        // Difficulty badge
                        Text(session.difficulty.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(difficultyColor(session.difficulty))
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Category
                        Text(session.category.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 8)
                    
                    // Start Training Button
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Start Training")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .background(categoryBackgroundColor(session.category))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func difficultyColor(_ difficulty: TrainingSession.Difficulty) -> Color {
        switch difficulty {
        case .beginner:
            return Color.green.opacity(0.8)
        case .intermediate:
            return Color.yellow.opacity(0.8)
        case .advanced:
            return Color.red.opacity(0.7)
        }
    }
    
    private func categoryBackgroundColor(_ category: TrainingSession.Category) -> Color {
        switch category {
        case .medical:
            return Color(red: 0.4, green: 0.3, blue: 0.6).opacity(0.6)
        case .aviation:
            return Color(red: 0.3, green: 0.4, blue: 0.6).opacity(0.6)
        case .music:
            return Color(red: 0.5, green: 0.3, blue: 0.6).opacity(0.6)
        case .engineering:
            return Color(red: 0.3, green: 0.3, blue: 0.5).opacity(0.6)
        }
    }
}
