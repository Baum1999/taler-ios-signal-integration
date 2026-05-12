/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

#if DEBUG2      // change to DEBUG
struct Spacer: View {
    let minLength: CGFloat?

    init(minLength: CGFloat? = nil) {
        self.minLength = minLength
    }

    var body: some View {
        SwiftUI.Spacer(minLength: minLength)
            .background {
                GeometryReader { geometry in
                    let isVertical = geometry.size.height > geometry.size.width

                    Color.yellow.opacity(0.3)
                        .frame(
                            width: isVertical ? 12 : nil,
                            height: isVertical ? nil : 12
//                            maxWidth: isVertical ? 12 : .infinity,
//                            maxHeight: isVertical ? .infinity : 12
                        )
                }
            }
    }
}
#endif
