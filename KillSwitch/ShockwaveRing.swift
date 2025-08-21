//
//  ShockwaveRing.swift
//  KillSwitch
//
//  Created by Samyak Pawar on 21/08/2025.
//


import SwiftUI

struct ShockwaveRing: View {
    var color: Color
    var trigger: Bool

    @State private var anim = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 3)
            .scaleEffect(anim ? 1.35 : 0.8)
            .opacity(anim ? 0 : 0.9)
            .blur(radius: 0.5)
            .onChange(of: trigger) { _, on in
                guard on else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    anim = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                    anim = false
                }
            }
    }
}