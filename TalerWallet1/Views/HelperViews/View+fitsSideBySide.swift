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
    static func fitsSideBySide(_ titles: [(String, UIFont)],
                         availableWidth: CGFloat,                       // total width available
                           sizeCategory: ContentSizeCategory,
                                spacing: CGFloat = HSPACING,            // between titles
                                padding: CGFloat = 20,
                               sameSize: Bool = true,
                               numViews: Int = 2)
    -> Bool {
//        let padding = 20.0        // TODO: depend on myListStyle
        let totalSpacing = spacing * CGFloat(numViews - 1)
        var totalWidth = padding + totalSpacing

        var maxTitleWidth = 0.0
        var minTitleWidth = 1000.0
        for (title, uiFont) in titles {
            let titleWidth = title.widthOfString(usingUIFont: uiFont, sizeCategory)
            if titleWidth > maxTitleWidth {
                maxTitleWidth = titleWidth
            }
            if titleWidth < minTitleWidth {
                minTitleWidth = titleWidth
            }
//            if availableWidth > 20 {
//                let widthStr = String(format: "%.2f + %.2f = %.2f", totalWidth, titleWidth, totalWidth + titleWidth)
//                print("❗️  \(title)  \(widthStr)")
//            }
            totalWidth += titleWidth
        }

        if sameSize {
            let nettoWidth = availableWidth - totalSpacing
            let singleWidth = nettoWidth / CGFloat(numViews)
            let neededWidth = padding + maxTitleWidth
//            if availableWidth > 20 {
//                let width1Str = String(format: "%.2f -spacing %.2f = %.2f / %d = %.2f", availableWidth, totalSpacing,
//                                       nettoWidth, numViews, singleWidth)
//                let width2Str = String(format: "%.2f +padding %.2f = %.2f", maxTitleWidth, padding, maxTitleWidth + padding)
//                print("❗️ available: \(width1Str)   needed: \(width2Str)")
//            }
            return neededWidth < singleWidth
        } else {
//            if availableWidth > 20 {
//                let totalStr = String(format: "%.2f -spacing %.2f = %.2f -padding %.2f = %.2f", totalWidth, totalSpacing,
//                                      totalWidth - totalSpacing, padding, totalWidth - totalSpacing - padding)
//                print("❗️ view width: \(availableWidth)   total: \(totalStr)")
//                let (amount, font) = titles[1]
//                print("❗️ view width: \(width)   total: \(totalStr)  min: \(minTitleWidth)  max: \(maxTitleWidth)  \(amount)")
//            }
            return totalWidth < availableWidth
        }
    }
}
