import CoreLocation
import SwiftUI

struct NeedsLocationView<Content: View>: View {
  var content: (CLLocation, LocationEvent) -> Content

  @Environment(\.errorStore)
  var errorStore

  @Environment(\.previewLocation)
  var previewLocation

  @Environment(\.services)
  private var services

  @State private var event: LocationEvent?

  private var resolvedEvent: LocationEvent? { previewLocation ?? event }

  var body: some View {
    Group {
      // The impediment is tested first because `accuracyLimited` arrives *with* a location: checked
      // the other way round it would pass the fix straight to the CDI, which would then fly the
      // run-in off a deliberately coarsened position.
      if let impediment = resolvedEvent?.diagnostics.impediment {
        NoLocationView(impediment: impediment)
      } else if let resolvedEvent, let location = resolvedEvent.location {
        content(location, resolvedEvent)
      } else {
        NoLocationView()
      }
    }
    .task {
      do {
        let provider = services.location
        await provider.start()
        if let stream = await provider.eventStream() {
          for try await event in stream {
            self.event = event
          }
        }
      } catch {
        errorStore.error = error
      }
    }
    .onDisappear {
      let provider = services.location
      Task { await provider.stop() }
    }
  }

  init(@ViewBuilder content: @escaping (CLLocation, LocationEvent) -> Content) {
    self.content = content
  }
}

#Preview("Location Available") {
  let helper = PreviewHelper()
  NeedsLocationView { _, _ in
    Text("Location available!")
  }
  .environment(\.previewLocation, helper.preIPEvent)
}

#Preview("No Location") {
  NeedsLocationView { _, _ in
    Text("Location available!")
  }
  .environment(\.previewLocation, nil)
}
