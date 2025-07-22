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
// MARK: -
struct FlippedLeftRight: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rotationEffect(.radians(Double.pi))
            .scaleEffect(x: 1, y: -1, anchor: .center)
    }
}

extension View {
    func flippedLeftRight() -> some View {
        modifier(FlippedLeftRight())
    }
}
// MARK: -
struct FlippedUpsideDown: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rotationEffect(.radians(Double.pi))
            .scaleEffect(x: -1, y: 1, anchor: .center)
    }
}

extension View {
    func flippedUpsideDown() -> some View {
        modifier(FlippedUpsideDown())
    }
}
