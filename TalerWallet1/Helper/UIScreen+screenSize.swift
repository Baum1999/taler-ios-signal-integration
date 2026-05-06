/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

fileprivate func maxValue<T: Comparable>(_ a: T, _ b: T) -> T {
    a > b ? a : b
}
fileprivate func maxSize(_ a: CGSize) -> CGFloat {
    maxValue(a.width, a.height)
}
fileprivate func minValue<T: Comparable>(_ a: T, _ b: T) -> T {
    a < b ? a : b
}
fileprivate func minSize(_ a: CGSize) -> CGFloat {
    minValue(a.width, a.height)
}


extension UIScreen {
    /// will flip in landscape mode
    static var screenSize: CGSize { UIScreen.main.bounds.size }
    /// we want portrait: height larger than width
    static var screenWidth: CGFloat { minSize(UIScreen.main.bounds.size) }
    static var screenHeight: CGFloat { maxSize(UIScreen.main.bounds.size) }
    static var hasNotch: Bool {
        let insets = UIApplication.shared.keyWindow?.safeAreaInsets
        let bottom = insets?.bottom ?? 0
        return bottom > 0
    }
    static var hasIsland: Bool {
        let insets = UIApplication.shared.keyWindow?.safeAreaInsets
        let left = insets?.left ?? 0
        let bottom = insets?.bottom ?? 0
        /// Portrait:   15PM 59,0,34    XS 38,0,29  8plus 20,0,0
        /// Landscape:      0,59,21         0,38,21         0,0,0
        return bottom > 30 || left > 50
    }
    static var horzInsets: CGFloat {
        let insets = UIApplication.shared.keyWindow?.safeAreaInsets
        let left = insets?.left ?? 0
        return left
    }
}
