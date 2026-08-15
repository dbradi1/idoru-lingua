//  SettingsView.swift
//  Settings tab — API key, server settings, app preferences.
//  Light warm theme matching HomeView.

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
        NavigationStack {
            ZStack {
                Color.linguaBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Connection status
                        statusCard
                            .padding(.horizontal, 20)

                        // API Key
                        apiKeyCard
                            .padding(.horizontal, 20)

                        // Server settings
                        serverSettingsCard
                            .padding(.horizontal, 20)

                        // App preferences
                        appPreferencesCard
                            .padding(.horizontal, 20)

                        // About
                        aboutCard
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
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

    // MARK: - Cards

    private var statusCard: some View {
        HStack {
            Image(systemName: appState.isOnline ? "wifi" : "wifi.slash")
                .font(.system(size: 20))
                .foregroundColor(appState.isOnline ? .linguaGood : .linguaAgain)
            VStack(alignment: .leading, spacing: 2) {
                Text("Server")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text(appState.isOnline ? "Connected via Tailscale" : "Offline")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.system(size: 17, weight: .semibold, design: .rounded))

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
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(apiKey.isEmpty ? Color.gray.opacity(0.3) : Color.linguaPrimary, in: .rect(cornerRadius: 12))
            .disabled(apiKey.isEmpty)
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var serverSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Server Settings")
                .font(.system(size: 17, weight: .semibold, design: .rounded))

            HStack {
                Text("Daily card cap")
                Spacer()
                Stepper("\(dailyCap)", value: $dailyCap, in: 5...50)
                    .tint(.linguaPrimary)
            }

            HStack {
                Text("Notification time")
                Spacer()
                TextField("08:00", text: $notificationTime)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            HStack {
                Text("Session timeout")
                Spacer()
                Stepper("\(sessionTimeout) min", value: $sessionTimeout, in: 5...30)
                    .tint(.linguaPrimary)
            }

            HStack {
                Text("Audio rate")
                Spacer()
                Slider(value: $audioRate, in: 0.5...2.0, step: 0.1)
                    .tint(.linguaPrimary)
                    .frame(width: 120)
                Text(String(format: "%.1fx", audioRate))
                    .frame(width: 40)
                    .font(.system(size: 14, weight: .medium))
            }

            Button {
                Task { await saveSettings() }
            } label: {
                Text(saving ? "Saving..." : "Save Settings")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(saving ? Color.gray.opacity(0.3) : Color.linguaPrimary, in: .rect(cornerRadius: 12))
            .disabled(saving)
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var appPreferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("App Preferences")
                .font(.system(size: 17, weight: .semibold, design: .rounded))

            Toggle(isOn: $hapticFeedback) {
                Text("Haptic feedback")
                    .font(.system(size: 15))
            }
            .tint(.linguaPrimary)

            Toggle(isOn: $autoPlayPronunciation) {
                Text("Auto-play pronunciation")
                    .font(.system(size: 15))
            }
            .tint(.linguaPrimary)

            HStack {
                Text("Font size")
                Spacer()
                Picker("", selection: $fontSize) {
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .tint(.linguaPrimary)
            }
        }
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var aboutCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Version")
                    .foregroundColor(.secondary)
                Spacer()
                Text("0.1.0")
                    .fontWeight(.medium)
            }
            HStack {
                Text("Server")
                Spacer()
                Text(appState.isOnline ? "Connected" : "Offline")
                    .foregroundColor(appState.isOnline ? .linguaGood : .linguaAgain)
                    .fontWeight(.medium)
            }
        }
        .font(.system(size: 15))
        .padding(16)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
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