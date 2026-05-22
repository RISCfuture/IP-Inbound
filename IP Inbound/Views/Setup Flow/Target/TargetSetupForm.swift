import Defaults
import SwiftUI

struct TargetSetupForm: View {
  @Bindable var target: Target

  @Default(.coordinateFormat)
  private var coordinateFormat

  @State private var editingCoordinates = false
  @State private var findLocationShown = false

  @ViewBuilder private var formattedCoordinate: some View {
    if let formatted = format(coordinate: target.coordinate) {
      Text(formatted)
    } else {
      Text("—")
    }
  }

  var body: some View {
    Form {
      Section {
        LabeledContent {
          TextField("", text: $target.name)
            .accessibilityIdentifier("targetNameField")
        } label: {
          Text("Name").foregroundStyle(.secondary)
        }

        LabeledContent {
          formattedCoordinate
            .onTapGesture(perform: cycleCoordinateFormat)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Change coordinate format")
            .accessibilityIdentifier("targetCoordinates")
        } label: {
          Text("Coordinates").foregroundStyle(.secondary)
        }

        Button(action: { editingCoordinates = true }, label: { Text("Set Coordinates…") })
          .accessibilityIdentifier("setCoordinatesButton")

        Button(action: { findLocationShown = true }, label: { Text("Find Location…") })
          .accessibilityIdentifier("findLocationButton")
      }
    }
    .sheet(isPresented: $editingCoordinates) {
      CoordinateEntryView(
        coordinate: target.coordinate,
        onAccept: { coordinate in
          target.coordinate = coordinate
          target.calculateDeclination()
          editingCoordinates = false
        },
        onCancel: { editingCoordinates = false }
      )
      .padding()
    }
    .sheet(isPresented: $findLocationShown) {
      FindLocationView { coord, title in
        target.coordinate = .init(coord)
        target.name = title
        findLocationShown = false
      }
    }
  }

  private func cycleCoordinateFormat() {
    switch coordinateFormat {
      case .degreesMinutesSeconds: Defaults[.coordinateFormat] = .degreesDecimalMinutes
      case .degreesDecimalMinutes: Defaults[.coordinateFormat] = .decimalDegrees
      case .decimalDegrees: Defaults[.coordinateFormat] = .utm
      case .utm: Defaults[.coordinateFormat] = .mgrs
      case .mgrs: Defaults[.coordinateFormat] = .degreesMinutesSeconds
    }
  }
}

#Preview {
  let helper = PreviewHelper()
  TargetSetupForm(target: helper.target())
    .modelContainer(helper.modelContainer)
}
