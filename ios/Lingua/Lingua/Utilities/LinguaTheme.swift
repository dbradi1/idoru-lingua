//  LinguaTheme.swift
//  Color palette and typography for Lingua — warm Italian tones.
//  Inspired by terracotta, espresso, Mediterranean blue.

import SwiftUI

extension Color {
    // Backgrounds — warm dark, not cold black
    static let linguaBackground = Color(red: 0.12, green: 0.10, blue: 0.09)  // warm espresso
    static let linguaSurface = Color(red: 0.18, green: 0.15, blue: 0.13)     // card surface
    static let linguaSurfaceLight = Color(red: 0.24, green: 0.20, blue: 0.17) // elevated surface

    // Accents — Mediterranean
    static let linguaAccent = Color(red: 0.85, green: 0.45, blue: 0.30)       // terracotta
    static let linguaBlue = Color(red: 0.25, green: 0.55, blue: 0.75)        // Mediterranean blue
    static let linguaGold = Color(red: 0.90, green: 0.75, blue: 0.40)        // golden hour

    // Grades
    static let linguaGood = Color(red: 0.30, green: 0.65, blue: 0.40)         // green
    static let linguaEasy = Color(red: 0.25, green: 0.55, blue: 0.75)         // blue
    static let linguaHard = Color(red: 0.85, green: 0.60, blue: 0.25)         // amber
    static let linguaAgain = Color(red: 0.80, green: 0.30, blue: 0.25)        // warm red
}

// MARK: - Typography
// Using system fonts with refined weights and sizes.
// SF Pro Rounded for headings (warmer, less corporate than SF Pro).
// SF Pro for body text (readable, native).

extension Font {
    // Display — app title, big numbers
    static let linguaDisplay = Font.system(size: 34, weight: .bold, design: .rounded)
    
    // Card text — the Italian phrase being learned (large, prominent)
    static let linguaCard = Font.system(size: 30, weight: .semibold, design: .serif)
    
    // Translation — English hint text
    static let linguaTranslation = Font.system(size: 20, weight: .regular, design: .default)
    
    // Section headings
    static let linguaHeading = Font.system(size: 22, weight: .semibold, design: .rounded)
    
    // Body
    static let linguaBody = Font.system(size: 16, weight: .regular, design: .default)
    
    // Caption / metadata
    static let linguaCaption = Font.system(size: 13, weight: .medium, design: .default)
    
    // Badge / pill labels
    static let linguaBadge = Font.system(size: 11, weight: .semibold, design: .rounded)
}