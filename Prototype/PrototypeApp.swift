import SwiftUI

@main
struct PrototypeApp: App {
    @StateObject private var viewModel = ViewModel()
    @State private var currentImmersionStyle: ImmersionStyle = .full
    
    var body: some Scene {
        // Main window for content
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        
        // Immersive space for 3D content
        ImmersiveSpace(id: "TrainingSpace") {
            ImmersiveView()
                .environmentObject(viewModel)
        }
        .immersionStyle(selection: $currentImmersionStyle, in: .progressive, .full)
    }
}
