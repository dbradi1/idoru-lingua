//  CardSessionView.swift
//  Card review session — the core learning experience.
//  Updated to warm light theme matching HomeView.

import SwiftUI
import AVFAudio

struct CardSessionView: View {
    @EnvironmentObject var appState: AppState
    @State private var session: APIClient.StartSessionResponse?
    @State private var currentCard: Card?
    @State private var gradeResult: APIClient.SubmitResponse?
    @State private var showingResult = false
    @State private var textAnswer = ""
    @State private var selectedOption: Int? = nil
    @State private var isStarting = false
    @State private var sessionEnded = false
    @State private var sessionSummary: APIClient.SessionSummary?
    @State private var errorMessage: String?
    @State private var isPlayingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentCardIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.linguaBackground
                    .ignoresSafeArea()

                VStack {
                    if !appState.isOnline {
                        offlineState
                    } else if session == nil && !isStarting {
                        startScreen
                    } else if isStarting {
                        ProgressView("Starting session...")
                    } else if let card = currentCard {
                        cardView(card)
                    } else if sessionEnded, let summary = sessionSummary {
                        SessionCompleteView(summary: summary) {
                            session = nil
                            currentCard = nil
                            sessionEnded = false
                            sessionSummary = nil
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
            .navigationTitle("Cards")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Something went wrong", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Offline

    private var offlineState: some View {
        ContentUnavailableView {
            Label("No Connection", systemImage: "wifi.slash")
        } description: {
            Text("Connect to Tailscale to start a session.")
        } actions: {
            Button("Check Again") {
                Task { await appState.checkConnection() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.linguaPrimary)
        }
    }

    // MARK: - Start screen

    private var startScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                Text("🇮🇹")
                    .font(.system(size: 56))

                Text("Ready to practice?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("Let's learn some Italian.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }

            Button {
                Task { await startSession() }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Session")
                }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Color.linguaPrimary, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Card view

    private func cardView(_ card: Card) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            if let session {
                ProgressView(value: Double(currentCardIndex), total: Double(session.totalCards))
                    .tint(.linguaPrimary)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .animation(.easeInOut(duration: 0.3), value: currentCardIndex)
            }

            // Card
            VStack(spacing: 16) {
                // Italian text + audio
                HStack(spacing: 12) {
                    Text(card.italianText)
                        .font(.linguaCard)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await playAudio(for: card.id) }
                    } label: {
                        Image(systemName: isPlayingAudio ? "speaker.wave.2.fill" : "speaker.wave.1.fill")
                            .font(.title2)
                            .foregroundColor(.linguaPrimary)
                    }
                }

                Text(card.englishText)
                    .font(.linguaTranslation)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Text(card.cardType.uppercased())
                    .font(.linguaBadge)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.linguaPrimary.opacity(0.1), in: .rect(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
            .background(Color.linguaSurface, in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Result or input
            if showingResult, let result = gradeResult {
                GradeResultView(result: result) {
                    advanceToNextCard(result)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            } else {
                answerInput(for: card)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }

            // Skip
            if !showingResult {
                Button("Skip") {
                    Task { await skipCard() }
                }
                .foregroundColor(.secondary)
                .font(.subheadline)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.bottom, 8)
            }

            Spacer()
        }
    }

    // MARK: - Answer input

    @ViewBuilder
    private func answerInput(for card: Card) -> some View {
        switch card.cardType {
        case "vocab", "phrase", "grammar":
            VStack(spacing: 12) {
                if card.cardType == "grammar", let note = card.grammarNote, !note.isEmpty {
                    Text("💡 \(note)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Text("Type the Italian phrase above:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("Type your answer...", text: $textAnswer)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 17))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    Task { await submitText() }
                } label: {
                    Text("Submit")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(textAnswer.isEmpty ? Color.gray.opacity(0.3) : Color.linguaPrimary, in: .rect(cornerRadius: 14))
                .disabled(textAnswer.isEmpty)
            }

        case "pronunciation":
            VStack(spacing: 12) {
                Button {
                    // TODO: Record audio and submit
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Record")
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .background(Color.linguaPrimary, in: .rect(cornerRadius: 14))

                Text("Pronunciation scoring coming soon")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

        default:
            Text("Tap to submit")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func startSession() async {
        isStarting = true
        do {
            let response = try await APIClient.shared.startSession(source: "on_demand")
            session = response
            currentCard = response.firstCard
            currentCardIndex = 0
            textAnswer = ""
            showingResult = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isStarting = false
    }

    private func submitText() async {
        guard let sessionId = session?.sessionId, !textAnswer.isEmpty else { return }
        do {
            let result = try await APIClient.shared.submitText(sessionId: sessionId, answer: textAnswer)
            gradeResult = result
            showingResult = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func skipCard() async {
        guard let sessionId = session?.sessionId else { return }
        do {
            let result = try await APIClient.shared.skipCard(sessionId: sessionId)
            advanceToNextCard(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func advanceToNextCard(_ result: APIClient.SubmitResponse) {
        if let next = result.nextCard {
            currentCard = next
            currentCardIndex += 1
            textAnswer = ""
            selectedOption = nil
            showingResult = false
            gradeResult = nil
        } else {
            Task { await endSession() }
        }
    }

    private func playAudio(for cardId: Int) async {
        do {
            isPlayingAudio = true
            let url = try await APIClient.shared.getCardAudio(cardId: cardId)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 2.0)) {
                isPlayingAudio = false
            }
        } catch {
            isPlayingAudio = false
            errorMessage = "Audio unavailable"
        }
    }

    private func endSession() async {
        guard let sessionId = session?.sessionId else { return }
        do {
            sessionSummary = try await APIClient.shared.endSession(sessionId: sessionId)
            sessionEnded = true
            currentCard = nil
        } catch {
            sessionEnded = true
            currentCard = nil
        }
    }
}

// MARK: - Grade Result

struct GradeResultView: View {
    let result: APIClient.SubmitResponse
    let onContinue: () -> Void

    private var gradeColor: Color {
        switch result.grade {
        case "again": return .linguaAgain
        case "hard": return .linguaHard
        case "good": return .linguaGood
        case "easy": return .linguaEasy
        default: return .gray
        }
    }

    private var gradeEmoji: String {
        switch result.grade {
        case "again": return "✗"
        case "hard": return "◐"
        case "good": return "✓"
        case "easy": return "★"
        default: return "?"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(gradeEmoji)
                .font(.system(size: 44))
                .foregroundColor(gradeColor)

            Text(result.grade.capitalized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(gradeColor)

            Text("Next review: \(result.nextInterval)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            if let pronunciation = result.pronunciation {
                VStack(spacing: 4) {
                    Text("Pronunciation: \(Int(pronunciation.overallScore))%")
                        .font(.subheadline)
                    ForEach(pronunciation.phonemes, id: \.sound) { phoneme in
                        HStack {
                            Text(phoneme.sound)
                                .font(.caption)
                            ProgressView(value: phoneme.score, total: 100)
                                .tint(phoneme.score >= 60 ? .linguaGood : .linguaHard)
                        }
                    }
                }
            }

            Button {
                onContinue()
            } label: {
                Text("Next Card →")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(gradeColor, in: .rect(cornerRadius: 14))
        }
        .padding(20)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

// MARK: - Session Complete

struct SessionCompleteView: View {
    let summary: APIClient.SessionSummary
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🎉")
                .font(.system(size: 56))

            Text("Session Complete!")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            VStack(spacing: 10) {
                StatRow(label: "Total", value: "\(summary.totalCards)", color: .primary)
                StatRow(label: "Good", value: "\(summary.good)", color: .linguaGood)
                StatRow(label: "Hard", value: "\(summary.hard)", color: .linguaHard)
                StatRow(label: "Again", value: "\(summary.again)", color: .linguaAgain)
                if summary.easy > 0 {
                    StatRow(label: "Easy", value: "\(summary.easy)", color: .linguaEasy)
                }
            }
            .padding(20)
            .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal, 40)

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Color.linguaPrimary, in: .rect(cornerRadius: 14))
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}