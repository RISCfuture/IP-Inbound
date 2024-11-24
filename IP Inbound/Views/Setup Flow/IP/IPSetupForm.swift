import SwiftUI

struct IPSetupForm: View {
    @Bindable var target: Target

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
                    switch target.offsetType {
                        case .distance:
                            HStack {
                                TextField("", value: $target.offsetDistance, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .accessibilityIdentifier("offsetDistanceField")
                                Text(localizedName(of: UnitLength.nauticalMiles, style: .short))
                            }
                        case .time:
                            HStack {
                                TextField("", value: $target.offsetTime, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .accessibilityIdentifier("offsetTimeField")
                                Text(localizedName(of: UnitDuration.minutes, style: .short))
                            }
                    }
                } label: {
                    Picker("", selection: $target.offsetType) {
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
                        Text(localizedName(of: UnitSpeed.knots, style: .short))
                    }
                } label: {
                    Text("Target Ground Speed").foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: target.offsetDistance) {
            let targetGroundSpeedMinutes = target.targetGroundSpeed / 60.0
            if target.offsetType == .distance {
                target.offsetTime = target.offsetDistance / targetGroundSpeedMinutes
            }
        }
        .onChange(of: target.offsetTime) {
            let targetGroundSpeedMinutes = target.targetGroundSpeed / 60.0
            if target.offsetType == .time {
                target.offsetDistance = target.offsetTime * targetGroundSpeedMinutes
            }
        }
        .onChange(of: target.offsetBearing) {
            if !(0..<360).contains(target.offsetBearing) {
                target.offsetBearing = target.offsetBearing >= 0 ?
                target.offsetBearing.truncatingRemainder(dividingBy: 360) :
                (target.offsetBearing.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            }
        }
    }
}

#Preview {
    let helper = PreviewHelper()
    IPSetupForm(target: helper.target())
        .modelContainer(helper.modelContainer)
}
