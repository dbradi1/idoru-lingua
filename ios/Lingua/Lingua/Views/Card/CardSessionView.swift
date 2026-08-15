//  CardSessionView.swift
//  Card review tab — per Figma Make CardsTab.tsx.
//  Coral gradient header, progress dots, tap-to-flip flashcard,
//  "Hard" / "Got it!" answer buttons, example sentence, skip link.

import SwiftUI
import AVFAudio

struct CardSessionView: View {
    @EnvironmentObject var appState: AppState
    @State private var session: APIClient.StartSessionResponse?
    @State private var currentCard: Card?
    @State private var isFlipped = false
    @State private var answered: String? = nil  // "hard", "got", nil
    @State private var isStarting = false
    @State private var sessionEnded = false
    @State private var sessionSummary: APIClient.SessionSummary?
    @State private var errorMessage: String?
    @State private var isPlayingAudio = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentCardIndex = 0
    @State private var totalCards = 0
    @State private var flipRotation: Double = 0

    // For the Figma header color — map card cluster to color
    private var headerColor: Color {
        guard let card = currentCard else { return .linguaBlue }
        // Use cluster ID to pick a color — for now use blue as default
        // since the Figma shows blue for café cards
        return .linguaBlue
    }

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
                        session = nil; currentCard = nil; sessionEnded = false
                        sessionSummary = nil; isFlipped = false; answered = nil
                        currentCardIndex = 0
                    }
                } else {
                    ProgressView().tint(.linguaPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
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
            Button("Check Again") { Task { await appState.checkConnection() } }
                .foregroundColor(.white)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Color.linguaPrimary, in: .rect(cornerRadius: 14))
            Spacer()
        }
    }

    // MARK: - Start Screen

    private var startScreen: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 12) {
                Text("🇮🇹").font(.system(size: 56))
                Text("Ready to practice?")
                    .font(.linguaHeading)
                    .foregroundColor(.linguaText)
                Text("Let's learn some Italian.")
                    .font(.linguaBody)
                    .foregroundColor(.linguaSubtext)
            }
            Button { Task { await startSession() } } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Session")
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(Color.linguaPrimary, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Card View (Figma layout)

    private func cardView(_ card: Card) -> some View {
        VStack(spacing: 0) {
            // ── Header with gradient ──
            cardHeader(card)

            // ── Card area ──
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Flashcard
                    flashCard(card)

                    // Example sentence (only when flipped)
                    if isFlipped, let note = card.grammarNote, !note.isEmpty {
                        exampleSentence(card, text: note)
                    }

                    // Answer buttons
                    answerButtons

                    // Skip link
                    if !isFlipped || answered == nil {
                        Button {
                            Task { await skipCard() }
                        } label: {
                            Text("Skip →")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(red: 0.73, green: 0.73, blue: 0.73))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Card Header

    private func cardHeader(_ card: Card) -> some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [headerColor, headerColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Memphis decorations
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .offset(x: 140, y: -40)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(25))
                    .offset(x: -120, y: 30)
            }
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                // Back arrow + title
                HStack(spacing: 8) {
                    Button {
                        // End current session and go back to start
                        if let sid = session?.sessionId {
                            Task { _ = try? await APIClient.shared.endSession(sessionId: sid) }
                        }
                        session = nil; currentCard = nil; isFlipped = false
                        answered = nil; currentCardIndex = 0
                    } label: {
                        Text("←")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2), in: .rect(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Italian Practice")
                            .font(.system(size: 11, weight: .medium, design: .serif))
                            .italic()
                            .foregroundColor(.white.opacity(0.75))
                        Text("Card Review \(card.emojiForCard)")
                            .font(.system(size: 20, weight: .heavy, design: .serif))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }

                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<max(totalCards, 1), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 99)
                            .fill(i <= currentCardIndex ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(height: 130)
        .clipped()
    }

    // MARK: - Flashcard (tap to flip)

    private func flashCard(_ card: Card) -> some View {
        VStack(spacing: 12) {
            Text(card.emojiForCard)
                .font(.system(size: 56))

            Text(card.italianText)
                .font(.system(size: 34, weight: .heavy, design: .serif).italic())
                .foregroundColor(.linguaText)
                .multilineTextAlignment(.center)

            if !isFlipped {
                Text("tap to reveal →")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.73, green: 0.73, blue: 0.73))
            } else {
                // Divider
                Rectangle()
                    .fill(Color(red: 0.94, green: 0.91, blue: 0.86))
                    .frame(height: 1)

                Text(card.englishText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaTextSecondary)

                // Audio button
                Button {
                    Task { await playAudio(for: card.id) }
                } label: {
                    Image(systemName: isPlayingAudio ? "speaker.wave.2.fill" : "speaker.wave.1.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.linguaPrimary)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(Color.linguaSurface, in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    answered == "got" ? Color.linguaGreen :
                    answered == "hard" ? Color.linguaPrimary :
                    Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isFlipped.toggle()
            }
        }
    }

    // MARK: - Example Sentence

    private func exampleSentence(_ card: Card, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.linguaTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.98, green: 0.96, blue: 0.93), in: .rect(cornerRadius: 16))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(headerColor)
                .frame(width: 4)
        }
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Answer Buttons

    private var answerButtons: some View {
        HStack(spacing: 12) {
            // Hard button (coral outline)
            Button {
                Task { await gradeCard(grade: "hard") }
            } label: {
                Text("✗ Hard")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Color.clear, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.linguaPrimary, lineWidth: 2)
            )
            .opacity(isFlipped ? 1 : 0.35)
            .disabled(!isFlipped)

            // Got it button (green outline)
            Button {
                Task { await gradeCard(grade: "good") }
            } label: {
                Text("✓ Got it!")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.linguaGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Color.clear, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.linguaGreen, lineWidth: 2)
            )
            .opacity(isFlipped ? 1 : 0.35)
            .disabled(!isFlipped)
        }
    }

    // MARK: - Actions

    private func startSession() async {
        isStarting = true
        do {
            let response = try await APIClient.shared.startSession(source: "on_demand")
            session = response
            currentCard = response.firstCard
            totalCards = response.totalCards
            currentCardIndex = 0
            isFlipped = false
            answered = nil
        } catch { errorMessage = error.localizedDescription }
        isStarting = false
    }

    private func gradeCard(grade: String) async {
        guard let sessionId = session?.sessionId else { return }
        answered = grade == "hard" ? "hard" : "got"

        // Brief delay for visual feedback
        try? await Task.sleep(nanoseconds: 400_000_000)

        // Submit with the grade as the answer (the API expects text input)
        // For the Figma-style flow, we submit the Italian text as the "answer"
        // and the server grades it. For "hard" we submit a deliberately wrong answer
        // to force a "hard" or "again" grade, and for "got it" we submit the correct text.
        do {
            let answer: String
            if grade == "hard" {
                answer = "__hard__"  // Server will grade as wrong/hard
            } else {
                answer = currentCard?.italianText ?? ""  // Correct answer
            }
            let result = try await APIClient.shared.submitText(sessionId: sessionId, answer: answer)
            advanceToNextCard(result)
        } catch {
            // Fallback: skip to next card on error
            errorMessage = error.localizedDescription
        }
    }

    private func skipCard() async {
        guard let sessionId = session?.sessionId else { return }
        do {
            let result = try await APIClient.shared.skipCard(sessionId: sessionId)
            advanceToNextCard(result)
        } catch { errorMessage = error.localizedDescription }
    }

    private func advanceToNextCard(_ result: APIClient.SubmitResponse) {
        if let next = result.nextCard {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentCard = next
                currentCardIndex += 1
                isFlipped = false
                answered = nil
            }
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

// MARK: - Card emoji helper

private extension Card {
    var emojiForCard: String {
        let text = italianText.lowercased()
        if text.contains("caff") || text.contains("coffee") { return "☕" }
        if text.contains("cornetto") || text.contains("croissant") { return "🥐" }
        if text.contains("casa") || text.contains("house") { return "🏠" }
        if text.contains("ciao") || text.contains("hello") { return "👋" }
        if text.contains("numero") || text.contains("number") { return "🔢" }
        if text.contains("famig") || text.contains("family") { return "👨‍👩‍👧" }
        if text.contains("viagg") || text.contains("travel") { return "✈️" }
        if text.contains("buongiorno") || text.contains("good morning") { return "🌅" }
        if text.contains("grazie") || text.contains("thank") { return "🙏" }
        if text.contains("pizza") { return "🍕" }
        if text.contains("gelato") { return "🍨" }
        if text.contains("vino") { return "🍷" }
        if text.contains("acqua") { return "💧" }
        return "📖"
    }
}

// MARK: - Session Complete

struct SessionCompleteView: View {
    let summary: APIClient.SessionSummary
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🎉").font(.system(size: 56))
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
            .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
            .padding(.horizontal, 40)

            Button { onDismiss() } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
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
            Text(label).foregroundColor(.linguaSubtext)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundColor(color)
        }
    }
}