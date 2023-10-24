/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import UIKit

extension View {
    /// if sameSize then this searches for the longest title
    /// returns true if any of the strings in 'titles' wouldn't fit in a view 1/'numViews' of the size of 'width', with 'spacing'
    /// if !sameSize then all titles are added with spacing
    static func needVStack(_ titles: [(String, UIFont)],
                              width: CGFloat,           // total width available
                            spacing: CGFloat,           // between titles
                           sameSize: Bool = true,
                           numViews: Int = 2,
                           currency: String = "")
    -> Bool {
        let padding: CGFloat = 20        // TODO: depend on myListStyle
        var maxTitleWidth: CGFloat = 0
        var totalWidth = padding

        for (title, uiFont) in titles {
            let titleWidth = title.widthOfString(usingUIFont: uiFont)
            if titleWidth > maxTitleWidth {
                maxTitleWidth = titleWidth
            }
            totalWidth += titleWidth
        }

        let neededWidth = padding + maxTitleWidth
        let totalSpacing = spacing * CGFloat(numViews - 1)
        let availableWidth = (width / CGFloat(numViews)) - totalSpacing
        totalWidth += totalSpacing
        if sameSize {
            print("❗️\(currency) available: \(availableWidth)   needed: \(neededWidth)")
        } else {
            print("❗️\(currency) width: \(width)   total: \(totalWidth)")
        }
        return sameSize ? neededWidth > availableWidth
                        : totalWidth > width
    }
}
