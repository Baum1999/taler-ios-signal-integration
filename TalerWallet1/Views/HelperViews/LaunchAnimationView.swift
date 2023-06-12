/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

struct LaunchAnimationView: View {
    @State private var rotationDirection = false

    private let animationTimer = Timer
        .publish(every: 1.6, on: .current, in: .common)
        .autoconnect()

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            Image("taler-logo-2023-red")
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250)
                .rotationEffect(rotationDirection ? Angle(degrees: 0) : Angle(degrees: 900))
        }
            .onReceive(animationTimer) { timerValue in
                withAnimation(.easeInOut(duration: 1.9)) {
                    rotationDirection.toggle()
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
