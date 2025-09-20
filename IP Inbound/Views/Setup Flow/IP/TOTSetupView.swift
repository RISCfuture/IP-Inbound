import SwiftUI

struct TOTSetupView: View {
  @Bindable var target: Target
  @State private var timeOnTarget = Date()

  private let timeAdvanceNew = 30.0  // minutes after now, for new targets without TOTs
  private let timeAdvanceEdit = 5.0  // minutes after now, for TOTs in the past

  var body: some View {
    VStack(spacing: 20) {
      DatePicker(
        "Time on Target", selection: $timeOnTarget, in: Date()...,
        displayedComponents: .hourAndMinute
      )
      .labelsHidden()
      .datePickerStyle(.wheel)
      .accessibilityIdentifier("timeOnTargetPicker")

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
      // Check for launch argument override first
      let arguments = ProcessInfo.processInfo.arguments
      if let overrideIndex = arguments.firstIndex(of: "-totMinutesOverride"),
        overrideIndex + 1 < arguments.count,
        let minutes = Double(arguments[overrideIndex + 1])
      {
        // Set TOT to specified minutes from now
        let overrideTime = Date().addingTimeInterval(minutes * 60)
        var components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute], from: overrideTime)
        components.second = 0
        let roundedTime = Calendar.current.date(from: components) ?? overrideTime
        self.timeOnTarget = roundedTime
        target.timeOnTarget = roundedTime
      } else if timeOnTarget == Date(timeIntervalSince1970: 0) {
        // Only set default time if we haven't already initialized and no override
        if let targetTime = target.timeOnTarget {
          if targetTime < Date() {
            self.timeOnTarget = Date().addingTimeInterval(60 * timeAdvanceEdit)
          } else {
            self.timeOnTarget = targetTime
          }
        } else {
          timeOnTarget = Date().addingTimeInterval(60 * timeAdvanceNew)
        }
      }
    }
    .onChange(of: timeOnTarget) {
      // if TOT is in the past, assume it's tomorrow
      if timeOnTarget.timeIntervalSinceNow < 0 {
        let date = Calendar.current.date(byAdding: .day, value: 1, to: timeOnTarget)
        target.timeOnTarget = date
      } else {
        target.timeOnTarget = timeOnTarget
      }
    }
  }
}

#Preview {
  let helper = PreviewHelper()
  TOTSetupView(target: helper.target())
}
