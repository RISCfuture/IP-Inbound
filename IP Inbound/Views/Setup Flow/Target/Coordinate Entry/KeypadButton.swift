import SwiftUI

/// A consistent button style for all keypad views.
///
/// Keys adopt the iOS 26 Liquid Glass button style. Per the Human Interface Guidelines, glass
/// keys stay neutral — color and the prominent variant are reserved for primary actions, not a
/// grid of peer keys — so enabled and disabled keys are distinguished by the system's standard
/// `disabled` dimming rather than by an accent flood.
struct KeypadButton: View {
  /// Apple's minimum recommended touch-target size, shared by all keypad layouts.
  static let minTouchTarget: CGFloat = 44

  /// A neutral tint that gives the flat clear-glass keys visible substance on a light
  /// background without reading as an accent. Keys stay peers; accent is reserved for the
  /// accept/cancel actions.
  private static let keyTint = Color(.systemGray4)

  let label: String?
  let systemImage: String?
  let accessibilityLabel: String?
  let isActive: Bool
  let isBackspace: Bool
  let accessibilityIdentifier: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      KeypadButtonLabel(
        label: label,
        systemImage: systemImage,
        accessibilityLabel: accessibilityLabel
      )
    }
    .buttonStyle(.glass(.clear.tint(Self.keyTint)))
    .disabled(!isActive && !isBackspace)
    .accessibilityIdentifier(accessibilityIdentifier)
  }

  init(label: String, isActive: Bool = true, action: @escaping () -> Void) {
    self.label = label
    self.systemImage = nil
    self.accessibilityLabel = nil
    self.isActive = isActive
    self.isBackspace = false
    self.accessibilityIdentifier = "keypad-\(label)"
    self.action = action
  }

  init(
    systemImage: String,
    accessibilityLabel: String,
    isBackspace: Bool = false,
    action: @escaping () -> Void
  ) {
    self.label = nil
    self.systemImage = systemImage
    self.accessibilityLabel = accessibilityLabel
    self.isActive = true
    self.isBackspace = isBackspace
    self.accessibilityIdentifier = "keypad-\(accessibilityLabel)"
    self.action = action
  }
}

/// The glyph or digit shown inside a ``KeypadButton``, expanded to fill the button's frame so the
/// Liquid Glass background covers the whole touch target.
private struct KeypadButtonLabel: View {
  private static let labelFontSize: CGFloat = 24
  private static let imageFontSize: CGFloat = 20

  let label: String?
  let systemImage: String?
  let accessibilityLabel: String?

  var body: some View {
    Group {
      if let label {
        Text(label)
          .font(.system(size: Self.labelFontSize, weight: .medium))
      } else if let systemImage, let accessibilityLabel {
        Image(systemName: systemImage)
          .font(.system(size: Self.imageFontSize))
          .accessibilityLabel(accessibilityLabel)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(.rect)
  }
}

#Preview {
  VStack(spacing: 20) {
    HStack(spacing: 10) {
      KeypadButton(label: "1", action: {})
        .frame(width: 60, height: 60)
      KeypadButton(label: "A", isActive: false, action: {})
        .frame(width: 60, height: 60)
      KeypadButton(
        systemImage: "delete.left",
        accessibilityLabel: "Delete",
        isBackspace: true,
        action: {
        }
      )
      .frame(width: 60, height: 60)
    }
  }
  .padding()
}
