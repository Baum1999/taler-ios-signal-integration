/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct LaunchAnimationView: View {
    @State private var rotationEnabled = true
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            RotatingTaler(size: (350 < UIScreen.screenWidth) ? 200 : 250,
                      progress: true,
               rotationEnabled: $rotationEnabled)
                .accessibilityLabel(Text("Progress indicator", comment: "a11y"))
        }
    }
}
// MARK: -
struct RotatingTaler: View {
    let size: CGFloat
    let progress: Bool

    @Binding var rotationEnabled: Bool
    @State private var rotationDirection = false
#if TALER_WALLET
    let logo = "taler-logo-2023-blue"
#elseif TALER_NIGHTLY
    let logo = "taler-logo-2023-black"
#else   // GNU_TALER
    let logo = "taler-logo-2023-red"
#endif

    private let animationTimer = Timer
        .publish(every: 1.6, on: .current, in: .common)
        .autoconnect()

    var body: some View {
        Image(logo)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(rotationDirection ? Angle(degrees: 0) : Angle(degrees: 900))
            .accessibilityLabel(progress ? Text("In progress", comment: "a11y")
                                         : Text("Taler Logo", comment: "a11y"))       // decorative logo - with button function
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
