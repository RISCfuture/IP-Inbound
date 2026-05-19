import SwiftUI

/// A consistent button style for all keypad views
struct KeypadButton: View {
  let label: String?
  let systemImage: String?
  let accessibilityLabel: String?
  let isActive: Bool
  let isBackspace: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(backgroundColor)

        if let label {
          Text(label)
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(foregroundColor)
        } else if let systemImage, let accessibilityLabel {
          Image(systemName: systemImage)
            .font(.system(size: 20))
            .foregroundColor(foregroundColor)
            .accessibilityLabel(accessibilityLabel)
        }
      }
    }
    .disabled(!isActive && !isBackspace)
    .accessibilityIdentifier("keypad-\((label ?? accessibilityLabel)!)")
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

  private var foregroundColor: Color {
    if isBackspace {
      return Color.accentColor
    }
    if isActive {
      return .white
    }
    return .gray
  }

  init(label: String, isActive: Bool = true, action: @escaping () -> Void) {
    self.label = label
    self.systemImage = nil
    self.accessibilityLabel = nil
    self.isActive = isActive
    self.isBackspace = false
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
