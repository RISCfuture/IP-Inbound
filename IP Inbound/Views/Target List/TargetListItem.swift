import SwiftUI

struct TargetListItem: View {
    var target: Target
    @Binding var selectedTarget: Target?

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(target.name)
                if let coordinate = format(coordinate: target.coordinate) {
                    Text(coordinate)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .foregroundColor(.accentColor)
                .accessibilityLabel("Edit Target")
        }.onTapGesture { selectedTarget = target }
            .accessibilityIdentifier("targetListItem")
            .accessibilityAddTraits(.isLink)
    }
}

#Preview {
    @Previewable @State var selectedTarget: Target?
    let helper = PreviewHelper()

    List {
        TargetListItem(target: helper.target(), selectedTarget: $selectedTarget)
    }
}
