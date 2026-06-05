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
            Color(.systemGray3).ignoresSafeArea()
            RotatingTaler(size: (350 < UIScreen.screenWidth) ? 200 : 250,
                      progress: true,
                          once: true,
               rotationEnabled: $rotationEnabled)
                .accessibilityLabel(Text("Progress indicator", comment: "a11y"))
        }
    }
}
// MARK: -
struct RotatingTaler: View {
    let size: CGFloat
    let progress: Bool
    let once: Bool

    @Binding var rotationEnabled: Bool
    @State private var rotationDirection = false

    private let animationTimer = Timer
        .publish(every: 1.5, on: .current, in: .common)
        .autoconnect()

    var body: some View {
        let image = Image(TALER_LOGO)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .padding(10)
            .accessibilityLabel(progress ? Text("In progress", comment: "a11y")
                                         : Text("Taler Logo", comment: "a11y"))       // decorative logo - with button function
            .rotationEffect(rotationDirection ? Angle(degrees: 0) : Angle(degrees: once ? 900 : 720))
            .onReceive(animationTimer) { timerValue in
                if rotationEnabled {
                    if !once {
                        withAnimation(.easeInOut(duration: 1.5)) {
                            rotationDirection.toggle()
                        }
                    }
                }
            }
            .task {
                if once {
                    withAnimation(.easeInOut(duration: 2.0)) {
                        rotationDirection.toggle()
                    }
                }
            }
        if #available(iOS 26.0, *) {
            image
                .glassEffect(.clear)
        } else {
            image
                .background {
                    Capsule()
                        .fill(Color(.systemGray6).opacity(0.3))
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
