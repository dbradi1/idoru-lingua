//  CardSessionView.swift
//  Card review session — dark theme per Figma Make design.
//  Black bg, terracotta accents, type-to-answer input, submit flow.

import SwiftUI
import AVFAudio

struct CardSessionView: View {
    @EnvironmentObject var appState: AppState
    @State private var session: APIClient.StartSessionResponse?
    @State private var currentCard: Card?
    @State private var gradeResult: APIClient.SubmitResponse?
    @State private var showingResult = false
    @State private var textAnswer = ""
    @State private var isStarting = false
    @State private var sessionEnded = false
    @State private var sessionSummary: APIClient.SessionSummary?
    @State private var errorMessage: String?
    @State private var isPlayingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentCardIndex = 0

    var body: some View {
        ZStack {
            Color.linguaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if !appState.isOnline {
                    offlineState
                } else if session == nil && !isStarting {
                    startScreen
                } else if isStarting {
                    ProgressView("Starting session...")
                        .tint(.linguaPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        .tint(.linguaPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Offline

    private var offlineState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.linguaSubtext)
            Text("No Connection")
                .font(.linguaHeading)
                .foregroundColor(.linguaText)
            Text("Connect to Tailscale to start a session.")
                .font(.linguaBody)
                .foregroundColor(.linguaSubtext)
            Button("Check Again") {
                Task { await appState.checkConnection() }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.linguaPrimary, in: .rect(cornerRadius: 14))
            Spacer()
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
                    .font(.linguaHeading)
                    .foregroundColor(.linguaText)

                Text("Let's learn some Italian.")
                    .font(.linguaBody)
                    .foregroundColor(.linguaSubtext)
            }

            Button {
                Task { await startSession() }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Session")
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Color.linguaPrimary, in: .rect(cornerRadius: 18))
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Card view

    private func cardView(_ card: Card) -> some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    session = nil
                    currentCard = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.linguaSubtext)
                }
                Spacer()
                Text("Cards")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaText)
                Spacer()
                Color.clear.frame(width: 18)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Progress bar
            if let session {
                ProgressView(value: Double(currentCardIndex), total: Double(session.totalCards))
                    .tint(.linguaPrimary)
                    .frame(height: 4)
                    .clipShape(.rect(cornerRadius: 4))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .animation(.easeInOut(duration: 0.3), value: currentCardIndex)
            }

            // Card content
            VStack(spacing: 16) {
                // Italian text + audio
                HStack(spacing: 12) {
                    Text(card.italianText)
                        .font(.linguaCardItalic)
                        .foregroundColor(showingResult && gradeResult?.grade == "again" ? .linguaPrimary : .linguaText)
                        .multilineTextAlignment(.leading)

                    Button {
                        Task { await playAudio(for: card.id) }
                    } label: {
                        Image(systemName: isPlayingAudio ? "speaker.wave.2.fill" : "speaker.wave.1.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.linguaPrimary)
                    }
                }

                // English translation
                Text(card.englishText)
                    .font(.linguaTranslation)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.linguaSubtext)

                // Type badge
                Text(card.cardType.uppercased())
                    .font(.linguaBadge)
                    .foregroundColor(.linguaSubtext)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.linguaSurface2, in: .rect(cornerRadius: 20))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 48)

            // Result or input
            if showingResult, let result = gradeResult {
                GradeResultView(result: result) {
                    advanceToNextCard(result)
                }
                .padding(.horizontal, 24)
                .padding(.top, 36)
            } else {
                answerInput(for: card)
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
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
                        .foregroundColor(.linguaSubtext)
                }

                Text("Type the Italian phrase above:")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.linguaSubtext)

                TextField("Type your answer...", text: $textAnswer)
                    .font(.system(size: 16))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(Color.clear, in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.linguaBorder, lineWidth: 1)
                    )
                    .foregroundColor(.linguaText)

                Button {
                    Task { await submitText() }
                } label: {
                    Text("Submit")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(textAnswer.isEmpty ? .linguaSubtext : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                }
                .background(textAnswer.isEmpty ? Color.linguaSurface2 : Color.linguaPrimary, in: .rect(cornerRadius: 18))
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
                    .padding(.vertical, 17)
                }
                .background(Color.linguaPrimary, in: .rect(cornerRadius: 18))

                Text("Pronunciation scoring coming soon")
                    .font(.system(size: 13))
                    .foregroundColor(.linguaSubtext)
            }

        default:
            Text("Tap to submit")
                .font(.caption)
                .foregroundColor(.linguaSubtext)
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

// MARK: - Grade Result (Dark)

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
                .foregroundColor(.linguaSubtext)

            if let pronunciation = result.pronunciation {
                VStack(spacing: 4) {
                    Text("Pronunciation: \(Int(pronunciation.overallScore))%")
                        .font(.subheadline)
                        .foregroundColor(.linguaText)
                    ForEach(pronunciation.phonemes, id: \.sound) { phoneme in
                        HStack {
                            Text(phoneme.sound)
                                .font(.caption)
                                .foregroundColor(.linguaSubtext)
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
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
            }
            .background(gradeColor, in: .rect(cornerRadius: 18))
        }
        .padding(20)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.linguaBorder, lineWidth: 1)
        )
    }
}

// MARK: - Session Complete (Dark)

struct SessionCompleteView: View {
    let summary: APIClient.SessionSummary
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🎉")
                .font(.system(size: 56))

            Text("Session Complete!")
                .font(.linguaHeading)
                .foregroundColor(.linguaText)

            VStack(spacing: 10) {
                StatRow(label: "Total", value: "\(summary.totalCards)", color: .linguaText)
                StatRow(label: "Good", value: "\(summary.good)", color: .linguaGood)
                StatRow(label: "Hard", value: "\(summary.hard)", color: .linguaHard)
                StatRow(label: "Again", value: "\(summary.again)", color: .linguaAgain)
                if summary.easy > 0 {
                    StatRow(label: "Easy", value: "\(summary.easy)", color: .linguaEasy)
                }
            }
            .padding(20)
            .background(Color.linguaSurface, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.linguaBorder, lineWidth: 1)
            )
            .padding(.horizontal, 40)

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
            }
            .background(Color.linguaPrimary, in: .rect(cornerRadius: 18))
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
                .foregroundColor(.linguaSubtext)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}