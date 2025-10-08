import Defaults
import SwiftUI

struct TOTView: View {
  var fromTo: FromToMath
  var timeOnTarget: Date?
  var showSpeed = true
  var isPush = false

  @Default(.TOTDisplayMode)
  private var displayMode

  @Default(.distanceUnit)
  private var distanceDefault

  var body: some View {
    HStack {
      if showSpeed {
        Text(fromTo.speed.converted(to: distanceDefault.speedUnit), format: speedFormatStyle)
          .onTapGesture { cycleUnits() }
          .accessibilityAddTraits(.isButton)
          .accessibilityHint("Cycle speed units")
        Text("•")
      }
      Text(fromTo.distance.converted(to: distanceDefault.distanceUnit), format: distanceFormatStyle)
        .onTapGesture { cycleUnits() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Cycle distance units")
      if let timeOnTarget {
        Text("•")
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          switch displayMode {
            case .local:
              Text(timeOnTarget, format: localTOTFormatStyle)
                .onTapGesture { displayMode = .zulu }
                .accessibilityHint("Toggle local or zulu time")
                .accessibilityAddTraits(.isButton)
            case .zulu:
              Text(timeOnTarget, format: zuluTOTFormatStyle)
                .onTapGesture { displayMode = .local }
                .accessibilityHint("Toggle local or zulu time")
                .accessibilityAddTraits(.isButton)
          }
          Text(isPush ? "Push" : "TOT")
            .font(.caption)
            .textCase(.uppercase)
        }
      }
    }
    .fontWeight(.bold)
  }

  private func cycleUnits() {
    guard let index = DistanceUnit.allCases.firstIndex(of: distanceDefault) else {
      distanceDefault = .nauticalMiles
      return
    }

    let nextIndex = (index + 1) % DistanceUnit.allCases.count
    distanceDefault = DistanceUnit.allCases[nextIndex]
  }
}

#Preview {
  let helper = PreviewHelper()
  let target = helper.target()
  let math = IPTargetMath(location: helper.preIPLocation, target: target)

  TOTView(fromTo: math.pposToTarget!, timeOnTarget: target.timeOnTarget)
}
