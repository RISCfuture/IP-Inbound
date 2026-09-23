import IP_Inbound_Shared
import SwiftData
import SwiftUI

struct ContentView: View {
  /// How long the targets must sit unchanged before Spotlight is told about them, so a name typed
  /// a letter at a time is indexed once rather than once per letter.
  private static let indexingDelay = Duration.seconds(2)

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

  /// The targets as Spotlight is to see them, in a fixed order so that only a real change to one
  /// of them reads as a change.
  private var indexedTargets: [TargetSnapshot] {
    targets.map(\.snapshot).sorted { $0.id < $1.id }
  }

  var body: some View {
    @Bindable var errorStore = errorStore
    TargetListView(resumedTarget: resumedTarget)
      .alert("Something went wrong.", item: $errorStore.error) { _ in
      } message: { error in
        Text(errorMessage(for: error))
      }
      .task(id: indexedTargets) { await indexOnceSettled(indexedTargets) }
  }

  private func indexOnceSettled(_ targets: [TargetSnapshot]) async {
    guard (try? await Task.sleep(for: Self.indexingDelay)) != nil else { return }
    await TargetSpotlightIndex.shared.reindex(targets)
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
