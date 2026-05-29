import SwiftUI

struct AppProgressBar: View {
    var value: Double          // 0...1
    var color: Color
    var height: CGFloat = 8
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceAlt)
                Capsule().fill(color)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
    }
}
