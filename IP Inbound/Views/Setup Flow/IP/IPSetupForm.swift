import Defaults
import Foundation
import SwiftUI

struct IPSetupForm: View {
    @Bindable var target: Target

    @State private var offsetType = IPOffsetType.distance
    @State private var offsetDistance = 4.0
    @State private var offsetTime = 2.0

    @Default(.distanceUnit)
    private var distanceDefault

    var body: some View {
        Form {
            Section("") {
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
                    Text("Bearing").foregroundStyle(.secondary)
                }

                LabeledContent {
                    switch offsetType {
                        case .distance:
                            HStack {
                                TextField("", value: $offsetDistance, format: .number)
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
                                TextField("", value: $offsetTime, format: .number)
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
                    .labelsHidden()
                    .padding(.horizontal, -12)
                    .accessibilityIdentifier("offsetTypePicker")
                }

                LabeledContent {
                    HStack {
                        TextField("", value: $target.targetGroundSpeed, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("targetGroundSpeedField")
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
                    Text("Target Ground Speed").foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: offsetDistance) {
            target.setOffset(distance: .init(value: offsetDistance,
                                             unit: distanceDefault.distanceUnit))
            offsetTime = target.offsetTime
        }
        .onChange(of: offsetTime) {
            target.setOffset(time: .init(value: offsetTime,
                                         unit: .minutes))
            offsetDistance = target.offsetDistance
        }
    }
}

#Preview {
    let helper = PreviewHelper()
    IPSetupForm(target: helper.target())
        .modelContainer(helper.modelContainer)
}
