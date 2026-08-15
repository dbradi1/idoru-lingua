//  SettingsView.swift
//  Settings tab — dark theme per Figma Make design.
//  Profile card, achievements, preferences with toggle switches.

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
    @State private var autoPlayPronunciation = true
    @State private var saving = false
    @State private var savedMessage = false

    var body: some View {
        ZStack {
            Color.linguaBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text("Settings")
                        .font(.linguaHeading)
                        .foregroundColor(.linguaText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    // Profile card
                    profileCard
                        .padding(.horizontal, 24)

                    // Achievements
                    achievementsSection
                        .padding(.horizontal, 24)

                    // Preferences
                    preferencesSection
                        .padding(.horizontal, 24)

                    // API Key
                    apiKeyCard
                        .padding(.horizontal, 24)

                    // Server settings
                    serverSettingsCard
                        .padding(.horizontal, 24)

                    // About
                    aboutCard
                        .padding(.horizontal, 24)
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
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Text("🧑")
                    .font(.system(size: 30))
            }
            .frame(width: 60, height: 60)
            .background(Color.linguaSurface2, in: .circle())
            .overlay(
                RoundedRectangle(cornerRadius: 30).stroke(Color.linguaPrimary, lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("Drew Bradicich")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaText)
                Text("Intermediate · Level 12")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.linguaSubtext)
                Text("2,480 XP · 14 🔥")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaPrimary)
            }
            Spacer()
        }
        .padding(20)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACHIEVEMENTS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.linguaSubtext)
                .kerning(1.2)

            VStack(spacing: 10) {
                ForEach(achievementData, id: \.title) { a in
                    HStack(spacing: 14) {
                        Text(a.icon)
                            .font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.linguaText)
                            Text(a.desc)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.linguaSubtext)
                        }
                        Spacer()
                        if a.done {
                            Text("✓")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(.linguaPrimary)
                        }
                    }
                    .padding(14)
                    .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.linguaBorder, lineWidth: 1)
                    )
                    .opacity(a.done ? 1.0 : 0.45)
                }
            }
        }
    }

    private let achievementData: [(icon: String, title: String, desc: String, done: Bool)] = [
        ("🏅", "First Steps", "Completed your first lesson", true),
        ("🔥", "On Fire", "7-day streak reached", true),
        ("🎯", "Sharp Tongue", "10 perfect flashcard rounds", false),
        ("🏛️", "La Dolce Vita", "Complete all cultural lessons", false),
    ]

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PREFERENCES")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.linguaSubtext)
                .kerning(1.2)

            VStack(spacing: 2) {
                preferenceRow("Daily Reminder", isOn: .constant(true))
                preferenceRow("Sound Effects", isOn: .constant(true))
                preferenceRow("Haptic Feedback", isOn: $hapticFeedback)
                preferenceRow("Auto-play Pronunciation", isOn: $autoPlayPronunciation)
            }
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
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
    }

    // MARK: - API Key Card

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.linguaText)

            SecureField("Enter API key...", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                UserDefaults.standard.set(apiKey, forKey: "lingua_api_key")
                appState.apiKey = apiKey
                savedMessage = true
            } label: {
                Text("Save Key")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(apiKey.isEmpty ? .linguaSubtext : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(apiKey.isEmpty ? Color.linguaSurface2 : Color.linguaPrimary, in: .rect(cornerRadius: 14))
            .disabled(apiKey.isEmpty)
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
    }

    // MARK: - Server Settings

    private var serverSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Server Settings")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.linguaText)

            HStack {
                Text("Daily card cap")
                    .foregroundColor(.linguaText)
                Spacer()
                Stepper("\(dailyCap)", value: $dailyCap, in: 5...50)
                    .tint(.linguaPrimary)
            }

            HStack {
                Text("Notification time")
                    .foregroundColor(.linguaText)
                Spacer()
                TextField("08:00", text: $notificationTime)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .foregroundColor(.linguaText)
            }

            HStack {
                Text("Session timeout")
                    .foregroundColor(.linguaText)
                Spacer()
                Stepper("\(sessionTimeout) min", value: $sessionTimeout, in: 5...30)
                    .tint(.linguaPrimary)
            }

            HStack {
                Text("Audio rate")
                    .foregroundColor(.linguaText)
                Spacer()
                Slider(value: $audioRate, in: 0.5...2.0, step: 0.1)
                    .tint(.linguaPrimary)
                    .frame(width: 120)
                Text(String(format: "%.1fx", audioRate))
                    .frame(width: 40)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.linguaText)
            }

            Button {
                Task { await saveSettings() }
            } label: {
                Text(saving ? "Saving..." : "Save Settings")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(saving ? .linguaSubtext : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(saving ? Color.linguaSurface2 : Color.linguaPrimary, in: .rect(cornerRadius: 14))
            .disabled(saving)
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Version")
                    .foregroundColor(.linguaSubtext)
                Spacer()
                Text("0.1.0")
                    .fontWeight(.medium)
                    .foregroundColor(.linguaText)
            }
            HStack {
                Text("Server")
                    .foregroundColor(.linguaSubtext)
                Spacer()
                Text(appState.isOnline ? "Connected" : "Offline")
                    .foregroundColor(appState.isOnline ? .linguaGood : .linguaAgain)
                    .fontWeight(.medium)
            }
        }
        .font(.system(size: 15))
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
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
        if dailyCap != serverSettings?.dailyReviewCap { updates["daily_review_cap"] = AnyCodable(dailyCap) }
        if notificationTime != serverSettings?.notificationTime { updates["notification_time"] = AnyCodable(notificationTime) }
        if sessionTimeout != serverSettings?.sessionTimeoutMinutes { updates["session_timeout_minutes"] = AnyCodable(sessionTimeout) }
        if audioRate != serverSettings?.audioRate { updates["audio_rate"] = AnyCodable(audioRate) }

        if !updates.isEmpty {
            do {
                let updated = try await APIClient.shared.updateSettings(updates)
                serverSettings = updated
                dailyCap = updated.dailyReviewCap
                notificationTime = updated.notificationTime
                sessionTimeout = updated.sessionTimeoutMinutes
                audioRate = updated.audioRate
                savedMessage = true
            } catch {}
        }
        saving = false
    }
}