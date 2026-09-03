import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.errorStore)
  private var errorStore

  @Query private var targets: [Target]

  /// The target of a run that outlived the last process, so the pilot lands back on it rather than
  /// on an empty detail pane. Resolved here because this is the outermost view with a model context
  /// to resolve it against.
  private var resumedTarget: Target? {
    guard let runTargetID = BackgroundActivityHolder.shared.runTargetID else { return nil }
    return targets.first { $0.id == runTargetID }
  }

  var body: some View {
    TargetListView(resumedTarget: resumedTarget)
      .warmsLocation()
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
