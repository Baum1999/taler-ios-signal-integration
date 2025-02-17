/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct FlippedDirection: ViewModifier {
    @Environment(\.layoutDirection) var layoutDirection

    func body(content: Content) -> some View {
        let isLeft = layoutDirection == .leftToRight
        content
            .environment(\.layoutDirection, isLeft ? .rightToLeft : .leftToRight)
    }
}

extension View {
    func flippedDirection() -> some View {
        self.modifier(FlippedDirection())
    }
}
