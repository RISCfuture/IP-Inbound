import SwiftUI

/// A shared accept/cancel button bar used by every coordinate-entry keypad.
struct AcceptCancelBar: View {
  private static let iconScale: CGFloat = 0.6

  let baseline: CGFloat
  let isAcceptEnabled: Bool
  let onAccept: () -> Void
  let onCancel: () -> Void

  var body: some View {
    HStack {
      Spacer()
      Button(action: onCancel) {
        Image(systemName: "xmark")
          .resizable()
          .scaledToFit()
          .frame(height: iconHeight)
          .accessibilityLabel(Text("Cancel"))
      }
      .frame(height: baseline)
      Spacer()
      Button(action: onAccept) {
        Image(systemName: "checkmark")
          .resizable()
          .scaledToFit()
          .frame(height: iconHeight)
          .accessibilityLabel(Text("Accept"))
      }
      .frame(height: baseline)
      .disabled(!isAcceptEnabled)
      Spacer()
    }
  }

  private var iconHeight: CGFloat { baseline * Self.iconScale }

  init(
    baseline: CGFloat,
    isAcceptEnabled: Bool = true,
    onAccept: @escaping () -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.baseline = baseline
    self.isAcceptEnabled = isAcceptEnabled
    self.onAccept = onAccept
    self.onCancel = onCancel
  }
}

#Preview("Enabled") {
  AcceptCancelBar(baseline: 60, onAccept: {}, onCancel: {})
    .padding()
}

#Preview("Accept disabled") {
  AcceptCancelBar(baseline: 60, isAcceptEnabled: false, onAccept: {}, onCancel: {})
    .padding()
}
