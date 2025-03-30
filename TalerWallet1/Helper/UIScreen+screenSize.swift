/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

extension UIScreen {
    static var screenWidth: CGFloat { UIScreen.main.bounds.size.width }
    static var screenHeight: CGFloat { UIScreen.main.bounds.size.height }
    static var screenSize: CGSize { UIScreen.main.bounds.size }
    static var hasFaceID: Bool {
        let size = screenSize       // aspect ratio is 2.16
        if size.width > size.height {   // landscape
            return size.width/size.height > 2
        } else {                        // portrait
            return size.height/size.width > 2
        }
    }
    static var hasTouchID: Bool {
        let size = screenSize      // aspect ratio is 1.77
        if size.width > size.height {   // landscape
            return size.width/size.height < 2
        } else {                        // portrait
            return size.height/size.width < 2
        }
    }
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
