//  LinguaTheme.swift
//  Color palette and typography for Lingua — dark theme.
//  Ported from Figma Make design: pure black bg, terracotta accent.
//  DM Serif Display for headings, Nunito for body (rounded fallback).

import SwiftUI

extension Color {
    // Dark theme backgrounds
    static let linguaBackground = Color(red: 0.0, green: 0.0, blue: 0.0)          // pure black
    static let linguaSurface = Color(red: 0.10, green: 0.10, blue: 0.10)           // #1A1A1A
    static let linguaSurface2 = Color(red: 0.145, green: 0.145, blue: 0.145)       // #252525
    static let linguaBorder = Color(red: 0.18, green: 0.18, blue: 0.18)            // #2E2E2E

    // Text
    static let linguaText = Color(red: 1.0, green: 1.0, blue: 1.0)                 // white
    static let linguaSubtext = Color(red: 0.60, green: 0.60, blue: 0.60)           // #9A9A9A

    // Primary — terracotta
    static let linguaPrimary = Color(red: 0.78, green: 0.41, blue: 0.29)           // #C8694A
    static let linguaAccent = Color(red: 0.78, green: 0.41, blue: 0.29)

    // Lesson category colors (muted for dark theme)
    static let linguaCoral = Color(red: 0.78, green: 0.41, blue: 0.29)
    static let linguaBlue = Color(red: 0.35, green: 0.55, blue: 0.80)
    static let linguaGold = Color(red: 0.90, green: 0.70, blue: 0.30)
    static let linguaGreen = Color(red: 0.30, green: 0.67, blue: 0.43)
    static let linguaPurple = Color(red: 0.65, green: 0.45, blue: 0.80)

    // Grades
    static let linguaGood = Color(red: 0.30, green: 0.67, blue: 0.43)              // #4CAF50
    static let linguaEasy = Color(red: 0.25, green: 0.55, blue: 0.75)
    static let linguaHard = Color(red: 0.85, green: 0.60, blue: 0.25)
    static let linguaAgain = Color(red: 0.78, green: 0.41, blue: 0.29)             // terracotta for "again"

    // Legacy aliases for compatibility
    static let linguaSurfaceLight = Color(red: 0.10, green: 0.10, blue: 0.10)
}

// MARK: - Typography

extension Font {
    // DM Serif Display isn't available on iOS by default — use system serif
    static let linguaDisplay = Font.system(size: 26, weight: .heavy, design: .serif)
    static let linguaDisplayLarge = Font.system(size: 34, weight: .heavy, design: .serif)
    static let linguaCard = Font.system(size: 34, weight: .heavy, design: .serif)
    static let linguaCardItalic = Font.system(size: 34, weight: .heavy, design: .serif).italic()
    static let linguaTranslation = Font.system(size: 16, weight: .medium, design: .default)
    static let linguaHeading = Font.system(size: 24, weight: .heavy, design: .serif)
    static let linguaBody = Font.system(size: 15, weight: .regular, design: .rounded)
    static let linguaBodyS = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let linguaCaption = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let linguaBadge = Font.system(size: 11, weight: .bold, design: .rounded)
    static let linguaTab = Font.system(size: 10, weight: .bold, design: .rounded)
}

// MARK: - ShapeStyle conformance

extension ShapeStyle where Self == Color {
    static var linguaBackground: Color { .linguaBackground }
    static var linguaSurface: Color { .linguaSurface }
    static var linguaSurface2: Color { .linguaSurface2 }
    static var linguaSurfaceLight: Color { .linguaSurfaceLight }
    static var linguaBorder: Color { .linguaBorder }
    static var linguaText: Color { .linguaText }
    static var linguaSubtext: Color { .linguaSubtext }
    static var linguaPrimary: Color { .linguaPrimary }
    static var linguaAccent: Color { .linguaAccent }
    static var linguaCoral: Color { .linguaCoral }
    static var linguaBlue: Color { .linguaBlue }
    static var linguaGold: Color { .linguaGold }
    static var linguaGreen: Color { .linguaGreen }
    static var linguaPurple: Color { .linguaPurple }
    static var linguaGold2: Color { .linguaGold }
    static var linguaGood: Color { .linguaGood }
    static var linguaEasy: Color { .linguaEasy }
    static var linguaHard: Color { .linguaHard }
    static var linguaAgain: Color { .linguaAgain }
}

// MARK: - Notification Names
extension Notification.Name {
    static let switchToCardsTab = Notification.Name("switchToCardsTab")
}