import SwiftUI

struct TOTSetupView: View {
  @Bindable var target: Target

  private let timeAdvanceNew = 30.0  // minutes after now, for new targets without TOTs
  private let timeAdvanceEdit = 5.0  // minutes after now, for TOTs in the past

  var body: some View {
    VStack(spacing: 20) {
      TOTEntryView(
        timeOnTarget: target.timeOnTarget,
        targetCoordinate: target.coordinate,
        onAccept: { newTime in
          target.timeOnTarget = newTime
        },
        onCancel: {
          // In this context, cancel doesn't do anything since we're always showing the entry
        }
      )

      Spacer()

      HStack {
        NavigationLink(value: SetupFlowStep.IPSetup) {
          HStack {
            Image(systemName: "chevron.backward")
              .accessibilityHidden(true)
            Text("Define IP")
          }
        }.accessibilityIdentifier("defineIPButton")
        Spacer()
        NavigationLink(value: SetupFlowStep.fly) {
          HStack {
            Text("Fly!")
            Image(systemName: "chevron.forward")
              .accessibilityHidden(true)
          }
        }.accessibilityIdentifier("flyButton")
      }.padding(.horizontal)
    }
    .onAppear {
      // Set default time if not already set
      if target.timeOnTarget == nil {
        let defaultTime = Date().addingTimeInterval(60 * timeAdvanceNew)
        var components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute],
          from: defaultTime
        )
        components.second = 0
        target.timeOnTarget = Calendar.current.date(from: components) ?? defaultTime
      } else if let targetTime = target.timeOnTarget, targetTime < Date() {
        // If the saved time is in the past, update it
        let updatedTime = Date().addingTimeInterval(60 * timeAdvanceEdit)
        var components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute],
          from: updatedTime
        )
        components.second = 0
        target.timeOnTarget = Calendar.current.date(from: components) ?? updatedTime
      }
    }
  }
}

#Preview {
  let helper = PreviewHelper()
  TOTSetupView(target: helper.target())
}
