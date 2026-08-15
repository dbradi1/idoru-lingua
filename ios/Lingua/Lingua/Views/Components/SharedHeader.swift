//  SharedHeader.swift
//  Dark theme header for Home and Cards tabs.
//  Compact: greeting + stats row on black with surface cards.

import SwiftUI

struct SharedHeader: View {
    @EnvironmentObject var appState: AppState
    var streak: Int = 0
    var xp: Int = 0
    var words: Int = 0
    var cities: [CityProgress] = []

    var body: some View {
        VStack(spacing: 20) {
            // Greeting + profile
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ciao,")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.linguaSubtext)
                    Text("Drew! 🇮🇹")
                        .font(.linguaDisplay)
                        .foregroundColor(.linguaText)
                }
                Spacer()

                // Journey city icons
                HStack(spacing: 6) {
                    ForEach(cities.prefix(4)) { city in
                        Text(city.nameEmoji ?? "🏙️")
                            .font(.system(size: 18))
                            .opacity(city.isUnlocked == 1 ? 1.0 : 0.3)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Stats cards row
            HStack(spacing: 10) {
                HeaderStatCard(icon: "🔥", value: "\(streak)", label: "day streak")
                HeaderStatCard(icon: "⚡️", value: "\(xp)", label: "XP total")
                HeaderStatCard(icon: "📚", value: "\(words)", label: "words")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }
}

private struct HeaderStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 20))
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.linguaText)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.linguaSubtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
    }
}