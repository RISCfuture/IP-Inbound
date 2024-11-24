import Defaults
import SwiftUI

struct TOTView: View {
    var fromTo: FromToMath
    var timeOnTarget: Date?
    var showSpeed = true

    @Default(.TOTDisplayMode)
    private var displayMode

    var body: some View {
        HStack {
            if showSpeed {
                Text(fromTo.speed.converted(to: .knots), format: speedFormatStyle)
                Text("•")
            }
            Text(fromTo.distance.converted(to: .nauticalMiles), format: distanceFormatStyle)
            if let timeOnTarget {
                Text("•")
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
            }
        }
        .fontWeight(.bold)
    }
}

#Preview {
    let helper = PreviewHelper()
    let target = helper.target()
    let math = IPTargetMath(location: helper.preIPLocation, target: target)

    TOTView(fromTo: math.pposToTarget!, timeOnTarget: target.timeOnTarget)
}
