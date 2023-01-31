
import SwiftUI
import SymLog

struct LaunchAnimationView: View {
    private let symLog = SymLogV(0)
    @State private var rotationDirection = false

    private let animationTimer = Timer
        .publish(every: 1.4, on: .current, in: .common)
        .autoconnect()

    var body: some View {
        ZStack {
            Color.teal.ignoresSafeArea()
            Image(systemName: "hurricane")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .rotationEffect(rotationDirection ? Angle(degrees: 0) : Angle(degrees: 1080))
        }
            .onReceive(animationTimer) { timerValue in
                withAnimation(.easeInOut(duration: 1.9)) {
                    rotationDirection.toggle()
                }
            }
    }
}
struct LaunchAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchAnimationView()
    }
}
