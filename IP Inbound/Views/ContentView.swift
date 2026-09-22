import IP_Inbound_Shared
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
    @Bindable var errorStore = errorStore
    TargetListView(resumedTarget: resumedTarget)
      .alert("Something went wrong.", item: $errorStore.error) { _ in
      } message: { error in
        Text(errorMessage(for: error))
      }
  }

  private func errorMessage(for error: any Error) -> String {
    var parts = [error.localizedDescription]
    if let error = error as? any LocalizedError {
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
