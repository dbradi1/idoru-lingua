//  OfflineBanner.swift
//  Per Decision #28: offline banner shown when server unreachable.
//  "🔇 Can't reach Idoru Lingua server. Check that Tailscale is connected."

import SwiftUI

struct OfflineBanner: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("🔇")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Can't reach Lingua server")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Check that Tailscale is connected on your iPhone.")
                        .font(.caption2)
                }
                Spacer()
                Button("Retry") {
                    Task { await appState.checkConnection() }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.9))
            .foregroundColor(.white)
        }
    }
}