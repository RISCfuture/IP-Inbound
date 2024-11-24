import CoreLocation
import SwiftUI

struct NeedsLocationView<Content: View>: View {
    var content: (CLLocation, LocationEvent) -> Content

    @Environment(\.errorStore)
    var errorStore

    @Environment(\.previewLocation)
    var previewLocation

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
                await LocationStreamer.shared.start()
                let stream = await LocationStreamer.shared.producer?.consume()
                if let stream {
                    for try await event in stream {
                        self.event = event
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

    init(@ViewBuilder content: @escaping (CLLocation, LocationEvent) -> Content) {
        self.content = content
    }
}

#Preview {
    NeedsLocationView { _, _ in
        Text("Location available!")
    }
}
