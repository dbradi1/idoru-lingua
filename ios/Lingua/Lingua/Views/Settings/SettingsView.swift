//  SettingsView.swift
//  Settings tab — per Figma Make SettingsTab.tsx.
//  Coral gradient profile card, achievements, preferences toggles,
//  API key input, server settings (steppers + slider), about card.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKey = ""
    @State private var serverSettings: ServerSettings?
    @State private var dailyCap: Int = 20
    @State private var notificationTime = "08:00"
    @State private var sessionTimeout: Int = 10
    @State private var audioVoice = "it-IT-IsabellaNeural"
    @State private var audioRate: Double = 1.0
    @State private var hapticFeedback = true
    @State private var fontSize = "medium"
    @State private var autoPlayPronunciation = false
    @State private var dailyReminder = true
    @State private var soundEffects = true
    @State private var saving = false
    @State private var savedMessage = false
    @State private var deepLinkSaved = false

    // Achievement data (matching Figma)
    private let achievementData: [(icon: String, title: String, desc: String, done: Bool)] = [
        ("🏅", "First Steps", "Complete your first lesson", true),
        ("🔥", "On Fire", "7-day streak achieved", true),
        ("🎯", "Sharp Tongue", "95% accuracy in a session", false),
        ("🏛️", "La Dolce Vita", "Complete all A1 lessons", false),
    ]

    var body: some View {
        ZStack {
            Color.linguaBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .heavy, design: .serif))
                        .foregroundColor(.linguaText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // Profile card (coral gradient)
                    profileCard
                        .padding(.horizontal, 16)

                    // Achievements
                    sectionCard("Achievements") {
                        achievementsContent
                    }

                    // Preferences
                    sectionCard("Preferences") {
                        preferencesContent
                    }

                    // API Key
                    sectionCard("API Key") {
                        apiKeyContent
                    }

                    // Server Settings
                    sectionCard("Server Settings") {
                        serverSettingsContent
                    }

                    // About
                    sectionCard("About") {
                        aboutContent
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: "lingua_api_key") ?? ""
            hapticFeedback = UserDefaults.standard.bool(forKey: "lingua_haptic")
            fontSize = UserDefaults.standard.string(forKey: "lingua_font_size") ?? "medium"
            autoPlayPronunciation = UserDefaults.standard.bool(forKey: "lingua_auto_play_pron")
            Task { await loadSettings() }
        }
        .onChange(of: hapticFeedback) { UserDefaults.standard.set(hapticFeedback, forKey: "lingua_haptic") }
        .onChange(of: fontSize) { UserDefaults.standard.set(fontSize, forKey: "lingua_font_size") }
        .onChange(of: autoPlayPronunciation) { UserDefaults.standard.set(autoPlayPronunciation, forKey: "lingua_auto_play_pron") }
        .alert("Saved", isPresented: $savedMessage) { Button("OK") {} }
        .alert("API Key Added", isPresented: $deepLinkSaved) { Button("OK") {} }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkAPIKeyReceived)) { _ in
            apiKey = UserDefaults.standard.string(forKey: "lingua_api_key") ?? ""
            deepLinkSaved = true
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Text("🧑")
                    .font(.system(size: 30))
            }
            .frame(width: 60, height: 60)
            .background(Color.white.opacity(0.95), in: .rect(cornerRadius: 30))
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white.opacity(0.5), lineWidth: 3)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("Drew Bradicich")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("Intermediate · Level 12")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Text("2,480 XP · 14 🔥")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.linguaPrimary, Color.linguaPrimaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 22)
        )
        .shadow(color: Color.linguaPrimary.opacity(0.35), radius: 8, y: 4)
    }

    // MARK: - Section Card Helper

    private func sectionCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.linguaSubtext)
                .kerning(1)

            content()
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Achievements

    private var achievementsContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(achievementData.enumerated()), id: \.element.title) { idx, a in
                HStack(spacing: 12) {
                    Text(a.icon)
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.linguaText)
                        Text(a.desc)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.linguaSubtext)
                    }
                    Spacer()
                    if a.done {
                        Text("✓")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.linguaGood)
                    }
                }
                .padding(.vertical, 10)
                .opacity(a.done ? 1 : 0.45)

                if idx < achievementData.count - 1 {
                    Divider()
                        .background(Color.linguaDivider)
                }
            }
        }
    }

    // MARK: - Preferences

    private var preferencesContent: some View {
        VStack(spacing: 0) {
            preferenceRow("Daily Reminder", isOn: $dailyReminder)
            Divider().background(Color.linguaDivider)
            preferenceRow("Sound Effects", isOn: $soundEffects)
            Divider().background(Color.linguaDivider)
            preferenceRow("Haptic Feedback", isOn: $hapticFeedback)
            Divider().background(Color.linguaDivider)
            preferenceRow("Auto-play Pronunciation", isOn: $autoPlayPronunciation)
        }
    }

    private func preferenceRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.linguaText)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.linguaPrimary)
        }
        .padding(.vertical, 11)
    }

    // MARK: - API Key

    private var apiKeyContent: some View {
        HStack(spacing: 8) {
            SecureField("sk-ant-...", text: $apiKey)
                .font(.system(size: 13))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.linguaSurface2, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.linguaBorder, lineWidth: 1.5)
                )

            Button {
                UserDefaults.standard.set(apiKey, forKey: "lingua_api_key")
                appState.apiKey = apiKey
                savedMessage = true
            } label: {
                Text("Save")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .background(Color.linguaPrimary, in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Server Settings

    private var serverSettingsContent: some View {
        VStack(spacing: 0) {
            // Daily card cap
            HStack {
                Text("Daily card cap")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.linguaText)
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        if dailyCap > 5 { dailyCap -= 5 }
                    } label: {
                        Text("−")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.linguaPrimary)
                            .frame(width: 28, height: 28)
                            .background(Color.clear, in: .rect(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.linguaPrimary, lineWidth: 1.5)
                            )
                    }
                    Text("\(dailyCap)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.linguaText)
                        .frame(width: 28)
                    Button {
                        if dailyCap < 100 { dailyCap += 5 }
                    } label: {
                        Text("+")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.linguaPrimary)
                            .frame(width: 28, height: 28)
                            .background(Color.clear, in: .rect(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.linguaPrimary, lineWidth: 1.5)
                            )
                    }
                }
            }
            .padding(.vertical, 8)
            Divider().background(Color.linguaDivider)

            // Session timeout
            HStack {
                Text("Session timeout")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.linguaText)
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        if sessionTimeout > 5 { sessionTimeout -= 5 }
                    } label: {
                        Text("−")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.linguaPrimary)
                            .frame(width: 28, height: 28)
                            .background(Color.clear, in: .rect(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.linguaPrimary, lineWidth: 1.5)
                            )
                    }
                    Text("\(sessionTimeout)m")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.linguaText)
                        .frame(width: 40)
                    Button {
                        if sessionTimeout < 60 { sessionTimeout += 5 }
                    } label: {
                        Text("+")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.linguaPrimary)
                            .frame(width: 28, height: 28)
                            .background(Color.clear, in: .rect(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.linguaPrimary, lineWidth: 1.5)
                            )
                    }
                }
            }
            .padding(.vertical, 8)
            Divider().background(Color.linguaDivider)

            // Audio rate slider
            VStack(spacing: 8) {
                HStack {
                    Text("Audio rate")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.linguaText)
                    Spacer()
                    Text(String(format: "%.1f×", audioRate))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.linguaPrimary)
                }
                Slider(value: $audioRate, in: 0.5...2.0, step: 0.1)
                    .tint(.linguaPrimary)
            }
            .padding(.vertical, 10)

            // Save Settings button
            Button {
                Task { await saveSettings() }
            } label: {
                Text(saving ? "Saving..." : "Save Settings")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(saving ? Color.gray.opacity(0.3) : Color.linguaPrimary, in: .rect(cornerRadius: 12))
            .disabled(saving)
            .padding(.top, 8)
        }
    }

    // MARK: - About

    private var aboutContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Version")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.linguaTextSecondary)
                Spacer()
                Text("0.1.0")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.linguaText)
            }
            .padding(.vertical, 6)
            Divider().background(Color.linguaDivider)

            HStack {
                Text("Server status")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.linguaTextSecondary)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(appState.isOnline ? Color.linguaGood : Color.linguaAgain)
                        .frame(width: 8, height: 8)
                    Text(appState.isOnline ? "Online" : "Offline")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(appState.isOnline ? .linguaGood : .linguaAgain)
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Actions

    private func loadSettings() async {
        do {
            let settings = try await APIClient.shared.getSettings()
            serverSettings = settings
            dailyCap = settings.dailyReviewCap
            notificationTime = settings.notificationTime
            sessionTimeout = settings.sessionTimeoutMinutes
            audioVoice = settings.audioVoice
            audioRate = settings.audioRate
        } catch {}
    }

    private func saveSettings() async {
        saving = true
        var updates: [String: AnyCodable] = [:]
        if dailyCap != serverSettings?.dailyReviewCap {
            updates["daily_review_cap"] = AnyCodable(dailyCap)
        }
        if sessionTimeout != serverSettings?.sessionTimeoutMinutes {
            updates["session_timeout_minutes"] = AnyCodable(sessionTimeout)
        }
        if audioRate != serverSettings?.audioRate {
            updates["audio_rate"] = AnyCodable(audioRate)
        }
        if !updates.isEmpty {
            do {
                let updated = try await APIClient.shared.updateSettings(updates)
                serverSettings = updated
                dailyCap = updated.dailyReviewCap
                sessionTimeout = updated.sessionTimeoutMinutes
                audioRate = updated.audioRate
                savedMessage = true
            } catch {}
        }
        saving = false
    }
}