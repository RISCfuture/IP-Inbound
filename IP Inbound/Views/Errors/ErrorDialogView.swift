import SwiftUI

/// The modal card shown by ``ErrorView`` describing a user-facing error, including its description
/// and, when available, its failure reason and recovery suggestion.
struct ErrorDialogView: View {
  private static let stackSpacing: CGFloat = 20
  private static let cornerRadius: CGFloat = 12
  private static let shadowRadius: CGFloat = 12
  private static let collapsedScale = 0.8
  private static let hiddenOpacity = 0.0
  private static let shownOpacity = 1.0
  private static let animationDuration = 0.25

  let error: Error
  let isPresented: Bool

  var body: some View {
    VStack(spacing: Self.stackSpacing) {
      Spacer()
      Image(systemName: "exclamationmark.octagon")
        .imageScale(.large)
        .accessibilityHidden(true)
      Text("Something went wrong.")
        .font(.title)
      Text(error.localizedDescription)
        .multilineTextAlignment(.leading)
        .fontWeight(.bold)
      Spacer()

      if let error = error as? LocalizedError {
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
    .clipShape(.rect(cornerRadius: Self.cornerRadius))
    .shadow(radius: Self.shadowRadius)
    .scaleEffect(isPresented ? 1 : Self.collapsedScale)
    .opacity(isPresented ? Self.shownOpacity : Self.hiddenOpacity)
    .animation(.easeInOut(duration: Self.animationDuration), value: isPresented)
  }
}

#Preview {
  ErrorDialogView(
    error: Errors.TOTNotConfigured(target: "Example Target"),
    isPresented: true
  )
}
