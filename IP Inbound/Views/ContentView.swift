import SwiftUI

struct ContentView: View {
    var body: some View {
        TargetListView()
            .overlay(ErrorView().allowsHitTesting(false))
    }
}

#Preview {
    ContentView()
}
