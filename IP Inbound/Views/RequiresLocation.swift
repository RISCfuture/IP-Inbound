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

  @State private var hasLocation = false

  var body: some View {
    Group {
      if hasLocation {
        content()
      } else {
        NoLocationView()
      }
    }
    .task {
      do {
        await LocationStreamer.shared.start()
        let stream = await LocationStreamer.shared.producer?.consume()
        if let stream {
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
      Task { await LocationStreamer.shared.stop() }
    }
  }

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }
}

#Preview {
  RequiresLocation {
    Text("Location available!")
  }
}
