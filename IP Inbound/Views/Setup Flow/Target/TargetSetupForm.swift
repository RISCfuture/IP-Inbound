import Defaults
import SwiftUI

struct TargetSetupForm: View {
    @Bindable var target: Target

    @Default(.coordinateFormat)
    private var coordinateFormat

    @State private var editingCoordinates = false

    var body: some View {
        Form {
            Section("") {
                LabeledContent {
                    TextField("", text: $target.name)
                        .accessibilityIdentifier("targetNameField")
                } label: {
                    Text("Name").foregroundStyle(.secondary)
                }

                LabeledContent {
                    Text(format(coordinate: target.coordinate) ?? "<n/a>")
                        .onTapGesture {
                            switch coordinateFormat {
                                case .degreesMinutesSeconds: Defaults[.coordinateFormat] = .degreesDecimalMinutes
                                case .degreesDecimalMinutes: Defaults[.coordinateFormat] = .decimalDegrees
                                case .decimalDegrees: Defaults[.coordinateFormat] = .utm
                                case .utm: Defaults[.coordinateFormat] = .degreesMinutesSeconds
                                case .geoURI: Defaults[.coordinateFormat] = .degreesMinutesSeconds
                            }
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Change coordinate format")
                } label: {
                    Text("Coordinates").foregroundStyle(.secondary)
                }

                LabeledContent {
                } label: {
                    Button(action: { editingCoordinates = true }, label: { Text("Set Coordinates…") })
                }
            }
        }
        .sheet(isPresented: $editingCoordinates) {
            CoordinateEntryView(coordinate: target.coordinate, onAccept: { coordinate in
                target.coordinate = coordinate
                target.calculateDeclination()
                editingCoordinates = false
            }, onCancel: { editingCoordinates = false })
            .padding()
        }
    }
}

#Preview {
    let helper = PreviewHelper()
    TargetSetupForm(target: helper.target())
        .modelContainer(helper.modelContainer)
}
