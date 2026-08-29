import SwiftUI

struct ProcessingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.peekpopAccent)
                Text("만드는 중...")
                    .font(.body)
                    .foregroundStyle(.white)
            }
        }
    }
}
