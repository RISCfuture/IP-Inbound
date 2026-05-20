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

  var body: some View {
    Group {
      if let event, let location = previewLocation?.location ?? event.location {
        content(location, event)
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

#Preview {
  NeedsLocationView { _, _ in
    Text("Location available!")
  }
}
