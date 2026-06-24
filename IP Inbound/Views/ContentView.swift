import SwiftUI

struct ContentView: View {
  @Environment(\.errorStore)
  private var errorStore

  var body: some View {
    TargetListView()
      .alert(
        "Something went wrong.",
        isPresented: isErrorPresented,
        presenting: errorStore.error
      ) { _ in
        Button("OK") { errorStore.error = nil }
      } message: { error in
        Text(errorMessage(for: error))
      }
  }

  private var isErrorPresented: Binding<Bool> {
    Binding(
      get: { errorStore.error != nil },
      set: { isPresented in
        if !isPresented { errorStore.error = nil }
      }
    )
  }

  private func errorMessage(for error: any Error) -> String {
    var parts = [error.localizedDescription]
    if let error = error as? LocalizedError {
      parts.append(contentsOf: [error.failureReason, error.recoverySuggestion].compactMap(\.self))
    }
    return parts.joined(separator: "\n\n")
  }
}

#Preview {
  let helper = PreviewHelper()
  ContentView()
    .modelContainer(helper.modelContainer)
    .environment(\.previewLocation, helper.preIPEvent)
    .onAppear { helper.createTarget() }
}
