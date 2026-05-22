import SwiftUI

/// A consistent button style for all keypad views.
struct KeypadButton: View {
  /// Apple's minimum recommended touch-target size, shared by all keypad layouts.
  static let minTouchTarget: CGFloat = 44

  private static let cornerRadius: CGFloat = 8
  private static let labelFontSize: CGFloat = 24
  private static let imageFontSize: CGFloat = 20

  let label: String?
  let systemImage: String?
  let accessibilityLabel: String?
  let isActive: Bool
  let isBackspace: Bool
  let accessibilityIdentifier: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
          .fill(backgroundColor)

        if let label {
          Text(label)
            .font(.system(size: Self.labelFontSize, weight: .medium))
            .foregroundStyle(foregroundStyle)
        } else if let systemImage, let accessibilityLabel {
          Image(systemName: systemImage)
            .font(.system(size: Self.imageFontSize))
            .foregroundStyle(foregroundStyle)
            .accessibilityLabel(accessibilityLabel)
        }
      }
    }
    .disabled(!isActive && !isBackspace)
    .accessibilityIdentifier(accessibilityIdentifier)
  }

  private var backgroundColor: Color {
    if isBackspace {
      return Color.secondary.opacity(0.2)
    }
    if isActive {
      return Color.accentColor
    }
    return Color.gray.opacity(0.3)
  }

  private var foregroundStyle: Color {
    if isBackspace {
      return Color.accentColor
    }
    if isActive {
      return Color(.systemBackground)
    }
    return Color.gray
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
