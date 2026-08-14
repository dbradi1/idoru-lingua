//  Models.swift
//  All data models for the Lingua app.
//  Maps to the FastAPI backend response shapes per Decisions #28 + #9.

import Foundation

// MARK: - Card

struct Card: Codable, Identifiable, Hashable {
    let id: Int
    let clusterId: Int
    let cardType: String
    let italianText: String
    let englishText: String
    let grammarNote: String?
    let audioPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case clusterId = "cluster_id"
        case cardType = "card_type"
        case italianText = "italian_text"
        case englishText = "english_text"
        case grammarNote = "grammar_note"
        case audioPath = "audio_path"
    }
}

// MARK: - Session

struct SessionInfo: Codable, Identifiable {
    let id: String
    let startedAt: String
    let cardsTotal: Int
    let cardsCompleted: Int
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case startedAt = "started_at"
        case cardsTotal = "cards_total"
        case cardsCompleted = "cards_completed"
        case status
    }
}

typealias ActiveSession = SessionInfo

// MARK: - Pronunciation

struct PronunciationScore: Codable, Hashable {
    let overallScore: Double
    let phonemes: [PhonemeScore]

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case phonemes
    }
}

struct PhonemeScore: Codable, Hashable {
    let sound: String
    let score: Double
}

// MARK: - Progress

struct CityProgress: Codable, Identifiable {
    let id: Int
    let name: String
    let nameEmoji: String?
    let cefrLevel: String
    let theme: String
    let badgeName: String?
    let sortOrder: Int
    let cardCount: Int?
    let isUnlocked: Int
    let badgeEarned: Int
    let gateReached: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case nameEmoji = "name_emoji"
        case cefrLevel = "cefr_level"
        case theme
        case badgeName = "badge_name"
        case sortOrder = "sort_order"
        case cardCount = "card_count"
        case isUnlocked = "is_unlocked"
        case badgeEarned = "badge_earned"
        case gateReached = "gate_reached"
    }
}

struct ClusterStrength: Codable, Identifiable {
    let id: Int
    let name: String
    let sortOrder: Int
    let cardCount: Int
    let strength: Double

    enum CodingKeys: String, CodingKey {
        case id, name
        case sortOrder = "sort_order"
        case cardCount = "card_count"
        case strength
    }
}

// MARK: - Stats

struct RetentionPoint: Codable, Identifiable {
    var id: String { date }

    let date: String
    let reviews: Int
    let correct: Int
    let failed: Int
}

struct LeechCard: Codable, Identifiable {
    let id: Int
    let clusterId: Int
    let cardType: String
    let italianText: String
    let englishText: String
    let leechFailCount: Int
    let leechFlaggedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case clusterId = "cluster_id"
        case cardType = "card_type"
        case italianText = "italian_text"
        case englishText = "english_text"
        case leechFailCount = "leech_fail_count"
        case leechFlaggedAt = "leech_flagged_at"
    }
}

// MARK: - Settings

struct ServerSettings: Codable {
    let dailyReviewCap: Int
    let notificationTime: String
    let sessionTimeoutMinutes: Int
    let audioVoice: String
    let audioRate: Double

    enum CodingKeys: String, CodingKey {
        case dailyReviewCap = "daily_review_cap"
        case notificationTime = "notification_time"
        case sessionTimeoutMinutes = "session_timeout_minutes"
        case audioVoice = "audio_voice"
        case audioRate = "audio_rate"
    }
}

// MARK: - AnyCodable (for PATCH settings)

struct AnyCodable: Encodable {
    let value: Any

    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else {
            try container.encodeNil()
        }
    }
}