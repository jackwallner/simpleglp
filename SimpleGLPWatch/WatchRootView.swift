import SwiftUI

struct WatchRootView: View {
    @StateObject private var controller = WatchConnectivityController()

    var body: some View {
        VStack(spacing: 20) {
            Text("Simple GLP")
                .font(.headline)
            Button {
                controller.requestShotLog()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.brand)
                        .frame(width: 100, height: 100)
                    Image(systemName: "syringe.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            if let status = controller.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}
