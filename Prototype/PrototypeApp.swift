import SwiftUI

@main
struct PrototypeApp: App {
    @StateObject private var viewModel = ViewModel()
    @State private var currentImmersionStyle: ImmersionStyle = .mixed
    
    var body: some Scene {
        // Main window for content - will be hidden when immersive space opens
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 800, height: 600)
        
        // Immersive space for 3D content
        ImmersiveSpace(id: "TrainingSpace") {
            ImmersiveView()
                .environmentObject(viewModel)
        }
        .immersionStyle(selection: $currentImmersionStyle, in: .mixed)
    }
}
