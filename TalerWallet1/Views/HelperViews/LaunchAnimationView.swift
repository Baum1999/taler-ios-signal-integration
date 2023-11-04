/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

struct LaunchAnimationView: View {
    @State private var rotationEnabled = true
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            RotatingTaler(size: (350 < UIScreen.screenWidth) ? 200 : 250, rotationEnabled: $rotationEnabled)
        }
    }
}

struct RotatingTaler: View {
    let size: CGFloat
    @Binding var rotationEnabled: Bool
    @State private var rotationDirection = false

    private let animationTimer = Timer
        .publish(every: 1.6, on: .current, in: .common)
        .autoconnect()

    var body: some View {
        Image("taler-logo-2023-red")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(rotationDirection ? Angle(degrees: 0) : Angle(degrees: 900))
            .accessibilityLabel("Taler Logo")       // decorative logo - with button function
            .onReceive(animationTimer) { timerValue in
                if rotationEnabled {
                    withAnimation(.easeInOut(duration: 1.9)) {
                        rotationDirection.toggle()
                    }
                }
            }
    }
}
// MARK: -
struct LaunchAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchAnimationView()
    }
}
