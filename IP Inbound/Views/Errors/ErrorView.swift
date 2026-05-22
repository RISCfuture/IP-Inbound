import SwiftUI

struct ErrorView: View {
  private static let dimmingOpacity = 0.5
  private static let animationDuration = 0.25

  @Environment(\.errorStore)
  var errorStore

  @State private var showDialog = false

  var body: some View {
    if let error = errorStore.error {
      ZStack {
        ErrorDialogView(error: error, isPresented: showDialog)
        background
      }
      .onAppear { showDialog = true }
      .onDisappear { showDialog = false }
      .transition(.opacity)
      .animation(.easeInOut(duration: Self.animationDuration), value: errorStore.error != nil)
    }
  }

  private var background: some View {
    Color(.systemBackground)  // swiftlint:disable:this accessibility_trait_for_button
      .opacity(Self.dimmingOpacity)
      .blendMode(.darken)
      .ignoresSafeArea()
      .onTapGesture {}  // capture taps
      .transition(.opacity)
  }
}

#Preview {
  var errorStore: ErrorStore {
    let store = ErrorStore()
    store.error = Errors.TOTNotConfigured(target: "Example Target")
    return store
  }

  ErrorView()
    .environment(\.errorStore, errorStore)
}
