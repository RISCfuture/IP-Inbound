import SwiftUI

/// Gates a view on the availability of a location without re-firing its content on every
/// location update. Use this for views that need location to *exist* (e.g. to enable adding
/// a target) but don't consume live updates. For views that track the live stream — the Fly
/// view's flight instruments — use ``NeedsLocationView`` instead.
struct RequiresLocation<Content: View>: View {
  var content: () -> Content

  @Environment(\.errorStore)
  private var errorStore

  @Environment(\.previewLocation)
  private var previewLocation

  @Environment(\.services)
  private var services

  @State private var hasLocation = false

  private var locationPresent: Bool { hasLocation || previewLocation?.location != nil }

  var body: some View {
    Group {
      if locationPresent {
        content()
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
            let present = (previewLocation?.location ?? event.location) != nil
            if present != hasLocation { hasLocation = present }
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

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
}

#Preview("Location Available") {
  let helper = PreviewHelper()
  RequiresLocation {
    Text("Location available!")
  }
  .environment(\.previewLocation, helper.preIPEvent)
}

#Preview("No Location") {
  RequiresLocation {
    Text("Location available!")
  }
  .environment(\.previewLocation, nil)
}
