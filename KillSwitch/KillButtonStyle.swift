//
//  KillButtonStyle.swift
//  KillSwitch
//
//  Created by Samyak Pawar on 21/08/2025.
//


import SwiftUI

struct KillButtonStyle: ButtonStyle {
    struct Config {
        static let diameter: CGFloat = 180
        static let baseRed = Color(red: 0.85, green: 0.05, blue: 0.07)
        static let glowRed = Color(red: 1.0, green: 0.15, blue: 0.15)
        static let ringRed = Color(red: 1.0, green: 0.35, blue: 0.35)
        static let bezel = Color(white: 0.08)
        static let metal = LinearGradient(colors: [.gray.opacity(0.7), .black.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var isBusy: Bool
    @Binding var pressedFlag: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed || pressedFlag

        return ZStack {
            // Bezel / housing
            Circle()
                .fill(Config.metal)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.06), lineWidth: 2)
                        .blur(radius: 0.5)
                )
                .shadow(color: .black.opacity(0.9), radius: 16, x: 0, y: 14)
                .frame(width: Config.diameter + 44, height: Config.diameter + 44)

            // Inner recess
            Circle()
                .fill(Config.bezel)
                .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 6)
                .padding(16)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.04), lineWidth: 1)
                )

            // The red button
            Circle()
                .fill(
                    RadialGradient(colors: [
                        pressed ? Config.baseRed.opacity(0.95) : Config.baseRed,
                        Color(red: 0.5, green: 0, blue: 0)
                    ], center: .topLeading, startRadius: 5, endRadius: Config.diameter)
                )
                .overlay( // inner shadow to sell depth
                    Circle()
                        .stroke(.black.opacity(pressed ? 0.55 : 0.35), lineWidth: 10)
                        .blur(radius: 4)
                        .mask(Circle().padding(2))
                )
                .overlay( // text label
                    configuration.label
                        .foregroundStyle(.white.opacity(pressed ? 0.85 : 1))
                        .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
                )
                .shadow(color: (pressed ? .black.opacity(0.6) : .black.opacity(0.85)), radius: pressed ? 12 : 22, x: 0, y: pressed ? 6 : 16)
                .shadow(color: Config.glowRed.opacity(pressed ? 0.35 : 0.55), radius: pressed ? 24 : 40)
                .scaleEffect(pressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
                .frame(width: Config.diameter, height: Config.diameter)
                .overlay(
                    // Shockwave ring on press
                    ShockwaveRing(color: Config.ringRed.opacity(0.8), trigger: pressed)
                        .allowsHitTesting(false)
                )
        }
        .padding(0)
        .contentShape(Rectangle())
        .onChange(of: isBusy) { _, busy in
            if !busy {
                // release the fake-pressed flag after a beat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        pressedFlag = false
                    }
                }
            }
        }
    }
}
