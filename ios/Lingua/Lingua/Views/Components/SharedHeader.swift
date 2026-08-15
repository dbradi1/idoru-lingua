//  SharedHeader.swift
//  Light theme header — coral gradient with Memphis decorations.
//  Greeting + stat cards with frosted glass effect.
//  Per Figma Make HomeTab.tsx: inline header used by HomeView.

import SwiftUI

struct SharedHeader: View {
    @EnvironmentObject var appState: AppState
    var streak: Int = 0
    var xp: Int = 0
    var words: Int = 0
    var cities: [CityProgress] = []

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.linguaPrimary, Color.linguaPrimaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Memphis decorations
            ZStack {
                // Top-right large circle
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .offset(x: 130, y: -40)

                // Smaller circle
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 50, height: 50)
                    .offset(x: 70, y: 0)

                // Bottom-left rotated rect
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(25))
                    .offset(x: -120, y: 50)

                // Top-left rotated rect
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(15))
                    .offset(x: -150, y: -20)

                // Bottom-right small circle
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 40, height: 40)
                    .offset(x: 100, y: 60)
            }
            .allowsHitTesting(false)

            // Content
            VStack(spacing: 16) {
                // Greeting row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ciao,")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Drew! 🇮🇹")
                            .font(.system(size: 30, weight: .heavy, design: .serif))
                            .foregroundColor(.white)
                    }
                    Spacer()

                    // Profile avatar
                    ZStack {
                        Text("🧑")
                            .font(.system(size: 22))
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.95), in: .rect(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Stat cards
                HStack(spacing: 8) {
                    HeaderStatCard(icon: "🔥", value: "\(streak)", label: "day streak")
                    HeaderStatCard(icon: "⚡️", value: "\(xp)", label: "XP total")
                    HeaderStatCard(icon: "📚", value: "\(words)", label: "words")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .frame(height: 220)
        .clipped()
    }
}

// MARK: - Header Stat Card (frosted glass)

private struct HeaderStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(icon)
                .font(.system(size: 16))
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.15), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}