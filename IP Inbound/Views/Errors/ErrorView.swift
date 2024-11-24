import SwiftUI

struct ErrorView: View {
    @Environment(\.errorStore)
    var errorStore

    @State private var showDialog = false

    var body: some View {
        if errorStore.error != nil {
            ZStack {
                errorView
                background
            }
            .onAppear { showDialog = true }
            .onDisappear { showDialog = false }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: errorStore.error != nil)
        }
    }

    private var background: some View {
        Color(.systemBackground) // swiftlint:disable:this accessibility_trait_for_button
            .opacity(0.5)
            .blendMode(.darken)
            .ignoresSafeArea()
            .onTapGesture { } // capture taps
            .transition(.opacity)
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.octagon")
                .imageScale(.large)
                .accessibilityHidden(true)
            Text("Something went wrong.")
                .font(.title)
            Text(errorStore.error!.localizedDescription)
                .multilineTextAlignment(.leading)
                .fontWeight(.bold)
            Spacer()

            if let error = errorStore.error as? LocalizedError {
                Group {
                    if let failureReason = error.failureReason {
                        Text(failureReason)
                    }
                    if let recoverySuggestion = error.recoverySuggestion {
                        Text(recoverySuggestion)
                    }
                }
                .font(.caption)
                .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 12)
        .scaleEffect(showDialog ? 1 : 0.8)
        .opacity(showDialog ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: showDialog)
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
