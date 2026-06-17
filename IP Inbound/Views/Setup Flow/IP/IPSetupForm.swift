import Defaults
import Foundation
import SwiftUI

struct IPSetupForm: View {
  private static let segmentedPickerInset = -12.0

  @Bindable var target: Target

  @State private var offsetType = IPOffsetType.distance

  @Default(.distanceUnit)
  private var distanceDefault

  // The offset's distance and time are two views of the same value, kept in sync
  // by `Target.setOffset(…)`. Binding both fields to `target` (the single source
  // of truth) rather than to mirrored `@State` avoids a write-back feedback loop
  // between the two representations.
  private var offsetDistance: Binding<Double> {
    .init(
      get: { target.offsetDistanceMeasurement.converted(to: distanceDefault.distanceUnit).value },
      set: { target.setOffset(distance: .init(value: $0, unit: distanceDefault.distanceUnit)) }
    )
  }

  private var offsetTime: Binding<Double> {
    .init(
      get: { target.offsetTime },
      set: { target.setOffset(time: .init(value: $0, unit: .minutes)) }
    )
  }

  var body: some View {
    Form {
      Section {
        LabeledContent {
          VStack {
            HStack {
              TextField("", value: $target.offsetBearing, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("offsetBearingField")
              Picker("", selection: $target.offsetBearingIsTrue) {
                Text("°M").tag(false)
                  .accessibilityIdentifier("offsetBearingMagnetic")
                Text("°T").tag(true)
                  .accessibilityIdentifier("offsetBearingTrue")
              }.pickerStyle(.segmented)
                .accessibilityIdentifier("offsetBearingReferencePicker")
            }
            HStack {
              Spacer()
              Text("Inbound: \(target.desiredTrack, format: .bearing)")
                .font(.footnote)
                .foregroundStyle(.primary)
            }
          }
        } label: {
          Text("Bearing")
            .foregroundStyle(.secondary)
        }

        LabeledContent {
          switch offsetType {
            case .distance:
              HStack {
                TextField("", value: offsetDistance, format: .number)
                  .multilineTextAlignment(.trailing)
                  .keyboardType(.numberPad)
                  .accessibilityIdentifier("offsetDistanceField")
                Picker("", selection: $distanceDefault) {
                  ForEach(DistanceUnit.allCases, id: \.self) { unit in
                    Text(localizedName(of: unit.distanceUnit, style: .short))
                      .tag(unit)
                  }
                }
                .labelsHidden()
                .accessibilityIdentifier("distanceUnitPicker")
              }
            case .time:
              HStack {
                TextField("", value: offsetTime, format: .number)
                  .multilineTextAlignment(.trailing)
                  .keyboardType(.numberPad)
                  .accessibilityIdentifier("offsetTimeField")
                Text(localizedName(of: UnitDuration.minutes, style: .short))
              }
          }
        } label: {
          Picker("", selection: $offsetType) {
            Text("Distance").tag(IPOffsetType.distance)
            Text("Time").tag(IPOffsetType.time)
          }
          .pickerStyle(.segmented)
          .labelsHidden()
          // Negative inset pulls the segmented picker out to the row edges,
          // cancelling the LabeledContent label column's leading padding.
          .padding(.horizontal, Self.segmentedPickerInset)
          .accessibilityIdentifier("offsetTypePicker")
        }

        LabeledContent {
          HStack {
            TextField("", value: $target.targetGroundSpeed, format: .number)
              .multilineTextAlignment(.trailing)
              .keyboardType(.numberPad)
              .accessibilityIdentifier("groundSpeedField")
            Picker("", selection: $distanceDefault) {
              ForEach(DistanceUnit.allCases, id: \.self) { unit in
                Text(localizedName(of: unit.speedUnit, style: .short))
                  .tag(unit)
              }
            }
            .labelsHidden()
            .accessibilityIdentifier("speedUnitPicker")
          }
        } label: {
          Text("Target Ground Speed")
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

#Preview {
  let helper = PreviewHelper()
  IPSetupForm(target: helper.target())
    .modelContainer(helper.modelContainer)
}
