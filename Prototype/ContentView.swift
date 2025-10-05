import SwiftUI
import RealityKit

struct ContentView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isShowingImmersiveSpace = false
    @State private var immersiveSpaceState: ImmersiveSpaceState = .closed
    
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "figure.wave")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("3D Replay Engine")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Select a training session to begin")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Training Sessions
                VStack(spacing: 16) {
                    ForEach(viewModel.trainingSessions) { session in
                        SessionCard(session: session) {
                            Task {
                                await selectSession(session)
                            }
                        }
                        .disabled(immersiveSpaceState == .inTransition)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Status indicator
                if immersiveSpaceState != .closed {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text(immersiveSpaceState == .inTransition ? "Opening immersive space..." : "Immersive space is open")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial, in: Capsule())
                }
            }
            .padding()
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
        
        do {
            let result = await openImmersiveSpace(id: "TrainingSpace")
            switch result {
            case .opened:
                immersiveSpaceState = .open
                isShowingImmersiveSpace = true
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
    }
    
    private func closeSpace() async {
        guard immersiveSpaceState == .open else { return }
        
        immersiveSpaceState = .inTransition
        
        await dismissImmersiveSpace()
        immersiveSpaceState = .closed
        isShowingImmersiveSpace = false
    }
}

// MARK: - Session Card Component
struct SessionCard: View {
    let session: TrainingSession
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(session.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(Int(session.duration))s")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .hoverEffect(.highlight)
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
