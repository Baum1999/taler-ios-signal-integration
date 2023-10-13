/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import UIKit

extension StringProtocol {
    func trimURL() -> String {
        if let url = URL(string: String(self)) {
            if let host = url.host {
                return host
            }
        }
        return String(self)
    }
}

extension String {
    func widthOfString(usingUIFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }
}
// This would be used like so:
// let uiFont = UIFont.systemFont(ofSize: 17, weight: .bold)
// let width = "SomeString".widthOfString(usingUIFont: uiFont)
