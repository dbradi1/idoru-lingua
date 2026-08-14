//  CardSessionView.swift
//  Card review session — the core learning experience.
//  Handles text, MC, and audio card types per Decision #9.
//  Skip is FSRS-neutral per Decision #9.
//  Per SOUL.md: warm, not perky. Concise feedback. Italian-first progression.

import SwiftUI

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

    var body: some View {
        NavigationStack {
            VStack {
                if !appState.isOnline {
                    ContentUnavailableView(
                        "Requires Connection",
                        systemImage: "wifi.slash",
                        description: Text("Connect to Tailscale to start a session")
                    )
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
            .navigationTitle("Cards")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Start screen

    private var startScreen: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.stack.fill.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Ready to practice?")
                .font(.linguaHeading)

            Button {
                Task { await startSession() }
            } label: {
                Text("Start Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: - Card view

    private func cardView(_ card: Card) -> some View {
        VStack(spacing: 16) {
            // Progress bar
            if let session {
                ProgressView(value: Double(session.totalCards - (gradeResult != nil ? 1 : 0)),
                             total: Double(session.totalCards))
                    .padding(.horizontal)
            }

            // Card content — show English as prompt, hide Italian until graded
            VStack(spacing: 20) {
                if showingResult {
                    // After grading: show the Italian text (the answer)
                    Text(card.italianText)
                        .font(.linguaCard)
                        .multilineTextAlignment(.center)
                }

                Text(card.englishText)
                    .font(.linguaTranslation)
                    .multilineTextAlignment(.center)

                // Card type badge
                Text(card.cardType.uppercased())
                    .font(.linguaBadge)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.linguaAccent.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.vertical, 40)

            if showingResult, let result = gradeResult {
                // Grade result
                GradeResultView(result: result) {
                    advanceToNextCard(result)
                }
            } else {
                // Answer input based on card type
                answerInput(for: card)
            }

            // Skip button
            if !showingResult {
                Button("Skip") {
                    Task { await skipCard() }
                }
                .foregroundColor(.secondary)
                .padding(.bottom)
            }
        }
        .padding()
    }

    // MARK: - Answer input

    @ViewBuilder
    private func answerInput(for card: Card) -> some View {
        switch card.cardType {
        case "vocab", "phrase":
            // Text input
            VStack(spacing: 12) {
                Text("Type the Italian translation:")
                    .font(.linguaCaption)
                    .foregroundColor(.secondary)
                TextField("Type your answer...", text: $textAnswer)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    Task { await submitText() }
                } label: {
                    Text("Submit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(textAnswer.isEmpty)
            }
            .padding(.horizontal)

        case "grammar":
            // Text input with explanation hint
            VStack(spacing: 12) {
                Text("Type the Italian translation:")
                    .font(.linguaCaption)
                    .foregroundColor(.secondary)
                if let note = card.grammarNote, !note.isEmpty {
                    Text("💡 \(note)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                TextField("Type your answer...", text: $textAnswer)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .autocorrectionDisabled()

                Button {
                    Task { await submitText() }
                } label: {
                    Text("Submit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(textAnswer.isEmpty)
            }
            .padding(.horizontal)

        case "pronunciation":
            // Audio recording (TODO: AVAudioEngine integration)
            VStack(spacing: 12) {
                Button {
                    // TODO: Record audio and submit
                } label: {
                    Label("Record", systemImage: "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Text("Pronunciation scoring coming soon")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

        default:
            // MC fallback
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
            textAnswer = ""
            selectedOption = nil
            showingResult = false
            gradeResult = nil
        } else {
            // Session complete
            Task { await endSession() }
        }
    }

    private func endSession() async {
        guard let sessionId = session?.sessionId else { return }
        do {
            sessionSummary = try await APIClient.shared.endSession(sessionId: sessionId)
            sessionEnded = true
            currentCard = nil
        } catch {
            // Session might already be auto-completed
            sessionEnded = true
            currentCard = nil
        }
    }
}

// MARK: - Grade Result

struct GradeResultView: View {
    let result: APIClient.SubmitResponse
    let onContinue: () -> Void

    var gradeColor: Color {
        switch result.grade {
        case "again": return .linguaAgain
        case "hard": return .linguaHard
        case "good": return .linguaGood
        case "easy": return .linguaEasy
        default: return .gray
        }
    }

    var gradeEmoji: String {
        switch result.grade {
        case "again": return "✗"
        case "hard": return "◐"
        case "good": return "✓"
        case "easy": return "★"
        default: return "?"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(gradeEmoji)
                .font(.system(size: 48))
                .foregroundColor(gradeColor)

            Text(result.grade.capitalized)
                .font(.linguaHeading)
                .foregroundColor(gradeColor)

            Text("Next review: \(result.nextInterval)")
                .font(.linguaCaption)
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

            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

// MARK: - Session Complete

struct SessionCompleteView: View {
    let summary: APIClient.SessionSummary
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Session Complete! 🎉")
                .font(.linguaDisplay)

            VStack(spacing: 8) {
                StatRow(label: "Total", value: "\(summary.totalCards)")
                StatRow(label: "Good", value: "\(summary.good)", color: .green)
                StatRow(label: "Hard", value: "\(summary.hard)", color: .orange)
                StatRow(label: "Again", value: "\(summary.again)", color: .red)
                if summary.easy > 0 {
                    StatRow(label: "Easy", value: "\(summary.easy)", color: .blue)
                }
            }
            .padding()
            .background(Color.linguaSurface)
            .cornerRadius(12)

            Button("Done", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding()
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