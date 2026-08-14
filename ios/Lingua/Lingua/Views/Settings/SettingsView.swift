//  SettingsView.swift
//  Settings tab — API key, server-side settings, app-local preferences.
//  Per Decision #9: 5 server-side settings via API, 6 app-local via UserDefaults.
//  Per Decision #28: Bearer auth via API key stored in Keychain (UserDefaults for dev).

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKey = ""
    @State private var serverSettings: ServerSettings?
    @State private var dailyCap: Int = 20
    @State private var notificationTime = "08:00"
    @State private var sessionTimeout: Int = 10
    @State private var audioVoice = "it-IT-LunaNeural"
    @State private var audioRate: Double = 1.0
    @State private var hapticFeedback = true
    @State private var fontSize = "medium"
    @State private var autoPlayPronunciation = true
    @State private var saving = false
    @State private var savedMessage = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Authentication") {
                    SecureField("API Key", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button("Save Key") {
                        UserDefaults.standard.set(apiKey, forKey: "lingua_api_key")
                        appState.apiKey = apiKey
                        savedMessage = true
                    }
                    .disabled(apiKey.isEmpty)
                }

                Section("Server Settings") {
                    Stepper("Daily card cap: \(dailyCap)", value: $dailyCap, in: 5...50)
                    TextField("Notification time", text: $notificationTime)
                    Stepper("Session timeout: \(sessionTimeout) min", value: $sessionTimeout, in: 5...30)
                    TextField("Audio voice", text: $audioVoice)
                    HStack {
                        Text("Audio rate")
                        Slider(value: $audioRate, in: 0.5...2.0, step: 0.1)
                        Text(String(format: "%.1fx", audioRate))
                            .frame(width: 40)
                    }

                    Button(saving ? "Saving..." : "Save Settings") {
                        Task { await saveSettings() }
                    }
                    .disabled(saving)
                }

                Section("App Preferences") {
                    Toggle("Haptic feedback", isOn: $hapticFeedback)
                    Toggle("Auto-play pronunciation", isOn: $autoPlayPronunciation)
                    Picker("Font size", selection: $fontSize) {
                        Text("Small").tag("small")
                        Text("Medium").tag("medium")
                        Text("Large").tag("large")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Server")
                        Spacer()
                        Text(appState.isOnline ? "Connected" : "Offline")
                            .foregroundColor(appState.isOnline ? .green : .red)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            apiKey = UserDefaults.standard.string(forKey: "lingua_api_key") ?? ""
            hapticFeedback = UserDefaults.standard.bool(forKey: "lingua_haptic")
            fontSize = UserDefaults.standard.string(forKey: "lingua_font_size") ?? "medium"
            autoPlayPronunciation = UserDefaults.standard.bool(forKey: "lingua_auto_play_pron")
            Task { await loadSettings() }
        }
        .onChange(of: hapticFeedback) {
            UserDefaults.standard.set(hapticFeedback, forKey: "lingua_haptic")
        }
        .onChange(of: fontSize) {
            UserDefaults.standard.set(fontSize, forKey: "lingua_font_size")
        }
        .onChange(of: autoPlayPronunciation) {
            UserDefaults.standard.set(autoPlayPronunciation, forKey: "lingua_auto_play_pron")
        }
        .alert("Saved", isPresented: $savedMessage) {
            Button("OK") {}
        }
    }

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
        if notificationTime != serverSettings?.notificationTime {
            updates["notification_time"] = AnyCodable(notificationTime)
        }
        if sessionTimeout != serverSettings?.sessionTimeoutMinutes {
            updates["session_timeout_minutes"] = AnyCodable(sessionTimeout)
        }
        if audioVoice != serverSettings?.audioVoice {
            updates["audio_voice"] = AnyCodable(audioVoice)
        }
        if audioRate != serverSettings?.audioRate {
            updates["audio_rate"] = AnyCodable(audioRate)
        }

        if !updates.isEmpty {
            do {
                let updated = try await APIClient.shared.updateSettings(updates)
                serverSettings = updated
                dailyCap = updated.dailyReviewCap
                notificationTime = updated.notificationTime
                sessionTimeout = updated.sessionTimeoutMinutes
                audioVoice = updated.audioVoice
                audioRate = updated.audioRate
                savedMessage = true
            } catch {}
        }
        saving = false
    }
}