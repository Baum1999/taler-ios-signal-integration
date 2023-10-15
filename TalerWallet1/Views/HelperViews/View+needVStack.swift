/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import UIKit

extension View {
    /// returns true if any of the strings in 'titles' wouldn't fit in a view 1/'numViews' the size of 'width', with 'spacing'
    static func needVStack(_ titles: [(String, UIFont)], width: CGFloat, spacing: CGFloat,
                           sameSize: Bool = true, numViews: Int = 2) -> Bool {
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

        return sameSize ? neededWidth > availableWidth
                        : totalWidth > width
    }
}
