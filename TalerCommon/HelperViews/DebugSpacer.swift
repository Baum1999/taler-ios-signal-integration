/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

#if TALER_NIGHTLY
struct Spacer: View {
    @AppStorage("developerMode") var developerMode: Bool = false
    @AppStorage("debugViews") var debugViews: Bool = false
    let minLength: CGFloat?

    init(minLength: CGFloat? = nil) {
        self.minLength = minLength
    }

    var body: some View {
        let spacer = SwiftUI.Spacer(minLength: minLength)
        if developerMode && debugViews {
            spacer.background {
                GeometryReader { geometry in
                    let isVertical = geometry.size.height > geometry.size.width

                    Color.yellow.opacity(0.3)
                        .frame(
                            width: isVertical ? 12 : nil,
                            height: isVertical ? nil : 12
                        )
                }
            }
        } else {
            spacer
        }
    }
}
#endif
