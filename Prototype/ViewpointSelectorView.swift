import SwiftUI

/// A view that allows the user to select a viewpoint from a list.
struct ViewpointSelectorView: View {
    @Binding var selectedViewpoint: Viewpoint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VIEWPOINT")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ForEach(Viewpoint.allCases) { viewpoint in
                Button(action: {
                    selectedViewpoint = viewpoint
                }) {
                    HStack {
                        Image(systemName: viewpoint.systemImage)
                        Text(viewpoint.rawValue)
                        Spacer()
                        if selectedViewpoint == viewpoint {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding()
                    .background(selectedViewpoint == viewpoint ? Color.accentColor : Color.clear)
                    .cornerRadius(8)
                }
                .foregroundColor(selectedViewpoint == viewpoint ? .white : .primary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
