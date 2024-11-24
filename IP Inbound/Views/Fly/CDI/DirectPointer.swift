import SwiftUI

private struct OpenChevron: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height

        let apex = CGPoint(x: width / 2, y: 0)
        let left = CGPoint(x: 0, y: height)
        let right = CGPoint(x: width, y: height)

        return Path { path in
            path.move(to: apex)
            path.addLine(to: left)
            path.move(to: apex)
            path.addLine(to: right)
        }
    }
}

struct DirectPointer: View {
    let label: String
    let color: Color

    var body: some View {
        ZStack {
            OpenChevron()
                .stroke(color, style: .init(lineWidth: 3, lineCap: .round, lineJoin: .miter, miterLimit: 4))
                .frame(width: 40, height: 25)

            Text(label)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(color)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(UIColor.systemBackground)))
                .offset(y: 10)
        }
    }
}

#Preview {
    VStack {
        DirectPointer(label: "IP", color: .yellow)
            .padding()
        DirectPointer(label: "T", color: .red)
            .padding()
    }
}
