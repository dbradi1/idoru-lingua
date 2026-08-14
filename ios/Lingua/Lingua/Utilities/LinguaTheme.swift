//  LinguaTheme.swift
//  Color palette for Lingua — warm Italian tones, not cyberpunk.
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