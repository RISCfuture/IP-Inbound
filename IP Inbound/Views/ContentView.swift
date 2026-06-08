import SwiftUI

struct ContentView: View {
  var body: some View {
    TargetListView()
      .overlay(ErrorView().allowsHitTesting(false))
  }
}

#Preview {
  let helper = PreviewHelper()
  ContentView()
    .modelContainer(helper.modelContainer)
    .environment(\.previewLocation, helper.preIPEvent)
    .onAppear { helper.createTarget() }
}
