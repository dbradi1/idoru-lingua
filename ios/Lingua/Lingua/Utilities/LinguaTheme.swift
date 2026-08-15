//  LinguaTheme.swift
//  Color palette and typography for Lingua — warm Mediterranean light theme.
//  Ported from Figma Make design: cream bg, coral accents, colorful lesson cards.
//  DM Serif Display for headings, Nunito for body (system serif/rounded fallback).

import SwiftUI

extension Color {
    // Light theme backgrounds
    static let linguaBackground = Color(red: 0.96, green: 0.93, blue: 0.88)          // #F5EDE0 warm cream
    static let linguaSurface = Color(red: 1.0, green: 1.0, blue: 1.0)                 // white cards
    static let linguaSurface2 = Color(red: 0.99, green: 0.98, blue: 0.97)             // off-white #FDFAF7
    static let linguaBorder = Color(red: 0.91, green: 0.88, blue: 0.84)               // #E8E0D5
    static let linguaDivider = Color(red: 0.96, green: 0.93, blue: 0.88)              // #F5EDE0

    // Text
    static let linguaText = Color(red: 0.20, green: 0.20, blue: 0.20)                 // #333
    static let linguaSubtext = Color(red: 0.60, green: 0.56, blue: 0.53)              // #999
    static let linguaTextSecondary = Color(red: 0.33, green: 0.33, blue: 0.33)        // #555

    // Primary — coral/terracotta
    static let linguaPrimary = Color(red: 0.91, green: 0.34, blue: 0.23)              // #E8563A
    static let linguaPrimaryDark = Color(red: 0.79, green: 0.26, blue: 0.16)          // #C9432A
    static let linguaPrimaryLight = Color(red: 0.94, green: 0.45, blue: 0.34)         // #F07356
    static let linguaAccent = Color(red: 0.91, green: 0.34, blue: 0.23)

    // Lesson category colors
    static let linguaCoral = Color(red: 0.91, green: 0.34, blue: 0.23)               // #E8563A
    static let linguaBlue = Color(red: 0.17, green: 0.37, blue: 0.65)                // #2B5EA7
    static let linguaGold = Color(red: 0.96, green: 0.64, blue: 0.16)                // #F4A228
    static let linguaGreen = Color(red: 0.24, green: 0.67, blue: 0.43)               // #3DAA6E
    static let linguaPurple = Color(red: 0.61, green: 0.36, blue: 0.90)              // #9B5DE5

    // Grades
    static let linguaGood = Color(red: 0.24, green: 0.67, blue: 0.43)               // #3DAA6E
    static let linguaEasy = Color(red: 0.25, green: 0.55, blue: 0.75)
    static let linguaHard = Color(red: 0.85, green: 0.60, blue: 0.25)
    static let linguaAgain = Color(red: 0.91, green: 0.34, blue: 0.23)              // coral

    // Legacy aliases
    static let linguaSurfaceLight = Color(red: 0.99, green: 0.98, blue: 0.97)
}

// MARK: - Typography

extension Font {
    static let linguaDisplay = Font.system(size: 30, weight: .heavy, design: .serif)
    static let linguaDisplayLarge = Font.system(size: 34, weight: .heavy, design: .serif)
    static let linguaCard = Font.system(size: 34, weight: .heavy, design: .serif)
    static let linguaCardItalic = Font.system(size: 34, weight: .heavy, design: .serif).italic()
    static let linguaTranslation = Font.system(size: 22, weight: .bold, design: .default)
    static let linguaHeading = Font.system(size: 28, weight: .heavy, design: .serif)
    static let linguaSubheading = Font.system(size: 22, weight: .heavy, design: .serif)
    static let linguaBody = Font.system(size: 15, weight: .regular, design: .rounded)
    static let linguaBodyS = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let linguaBodyBold = Font.system(size: 14, weight: .bold, design: .rounded)
    static let linguaCaption = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let linguaSmall = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let linguaBadge = Font.system(size: 11, weight: .bold, design: .rounded)
    static let linguaTab = Font.system(size: 9, weight: .bold, design: .rounded)
}

// MARK: - ShapeStyle conformance

extension ShapeStyle where Self == Color {
    static var linguaBackground: Color { .linguaBackground }
    static var linguaSurface: Color { .linguaSurface }
    static var linguaSurface2: Color { .linguaSurface2 }
    static var linguaSurfaceLight: Color { .linguaSurfaceLight }
    static var linguaBorder: Color { .linguaBorder }
    static var linguaDivider: Color { .linguaDivider }
    static var linguaText: Color { .linguaText }
    static var linguaSubtext: Color { .linguaSubtext }
    static var linguaPrimary: Color { .linguaPrimary }
    static var linguaPrimaryDark: Color { .linguaPrimaryDark }
    static var linguaPrimaryLight: Color { .linguaPrimaryLight }
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