//  LinguaTheme.swift
//  Color palette and typography for Lingua — warm Italian tones.
//  Inspired by terracotta, espresso, Mediterranean blue.

import SwiftUI

extension Color {
    // Backgrounds
    static let linguaBackground = Color(red: 0.98, green: 0.96, blue: 0.94)  // warm cream
    static let linguaSurface = Color(red: 1.0, green: 1.0, blue: 1.0)         // white card
    static let linguaSurfaceLight = Color(red: 0.95, green: 0.93, blue: 0.90) // off-white

    // Primary — coral/terracotta
    static let linguaPrimary = Color(red: 0.91, green: 0.36, blue: 0.31)      // coral red
    static let linguaAccent = Color(red: 0.91, green: 0.36, blue: 0.31)       // same as primary
    
    // Lesson category colors
    static let linguaCoral = Color(red: 0.91, green: 0.36, blue: 0.31)        // greetings
    static let linguaBlue = Color(red: 0.18, green: 0.36, blue: 0.54)        // café
    static let linguaGold = Color(red: 0.96, green: 0.66, blue: 0.24)        // numbers
    static let linguaGreen = Color(red: 0.30, green: 0.65, blue: 0.40)        // family
    static let linguaPurple = Color(red: 0.55, green: 0.35, blue: 0.65)      // travel

    // Grades
    static let linguaGood = Color(red: 0.30, green: 0.65, blue: 0.40)
    static let linguaEasy = Color(red: 0.25, green: 0.55, blue: 0.75)
    static let linguaHard = Color(red: 0.85, green: 0.60, blue: 0.25)
    static let linguaAgain = Color(red: 0.80, green: 0.30, blue: 0.25)
}

// MARK: - Typography

extension Font {
    static let linguaDisplay = Font.system(size: 34, weight: .bold, design: .rounded)
    static let linguaCard = Font.system(size: 30, weight: .semibold, design: .serif)
    static let linguaTranslation = Font.system(size: 20, weight: .regular, design: .default)
    static let linguaHeading = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let linguaBody = Font.system(size: 16, weight: .regular, design: .default)
    static let linguaCaption = Font.system(size: 13, weight: .medium, design: .default)
    static let linguaBadge = Font.system(size: 11, weight: .semibold, design: .rounded)
}

// MARK: - ShapeStyle conformance

extension ShapeStyle where Self == Color {
    static var linguaBackground: Color { .linguaBackground }
    static var linguaSurface: Color { .linguaSurface }
    static var linguaSurfaceLight: Color { .linguaSurfaceLight }
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