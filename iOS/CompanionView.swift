import SwiftUI

struct CompanionView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "applewatch")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("3-Line Calendar")
                .font(.title2.weight(.bold))
            Text("This app lives on your Apple Watch.\n\nAdd the “Next 3 Events” complication to your watch face, then open the watch app to grant calendar access.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}
