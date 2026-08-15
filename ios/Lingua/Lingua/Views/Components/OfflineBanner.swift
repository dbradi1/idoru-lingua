//  OfflineBanner.swift
//  Per Decision #28: offline banner shown when server unreachable.

import SwiftUI

struct OfflineBanner: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            Text("🔇")
            VStack(alignment: .leading, spacing: 2) {
                Text("Can't reach Lingua server")
                    .font(.system(size: 13, weight: .semibold))
                Text("Check that Tailscale is connected on your iPhone.")
                    .font(.system(size: 11))
            }
            Spacer()
            Button("Retry") {
                Task { await appState.checkConnection() }
            }
            .font(.system(size: 13, weight: .semibold))
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.linguaHard)
        .foregroundColor(.white)
    }
}