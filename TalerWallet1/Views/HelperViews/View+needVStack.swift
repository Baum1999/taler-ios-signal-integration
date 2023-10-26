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
                     correctForSize: CGFloat,
                            spacing: CGFloat,           // between titles
                           sameSize: Bool = true,
                           numViews: Int = 2)
    -> Bool {
        let padding: CGFloat = 20        // TODO: depend on myListStyle
        let totalSpacing = spacing * CGFloat(numViews - 1)
        var totalWidth = padding + totalSpacing

        var maxTitleWidth: CGFloat = 0
        var minTitleWidth: CGFloat = 1000
        for (title, uiFont) in titles {
            let titleWidth = title.widthOfString(usingUIFont: uiFont)
            let fixWidth = round(CGFloat(Int(20 * titleWidth * correctForSize))) / 20
            if fixWidth > maxTitleWidth {
                maxTitleWidth = fixWidth
            }
            if fixWidth < minTitleWidth {
                minTitleWidth = fixWidth
            }
            totalWidth += fixWidth
        }

        if sameSize {
            let availableWidth = (width / CGFloat(numViews)) - totalSpacing
            let neededWidth = padding + maxTitleWidth
//            if width > 20 {
//                print("❗️ available: \(availableWidth)   needed: \(neededWidth)")
//            }
            return neededWidth > availableWidth
        } else {
//            if width > 20 {
//                let (amount, font) = titles[1]
//                print("❗️ view width: \(width)   total: \(totalWidth)  min: \(minTitleWidth)  max: \(maxTitleWidth)  \(amount)")
//            }
            return totalWidth > width
        }
    }

    static func correctForSize(_ sizeCategory: ContentSizeCategory) -> CGFloat {
        return switch sizeCategory {
            case .extraSmall: 0.7
            case .small: 0.8
            case .medium: 0.9
            case .large: 1.0
            case .extraLarge: 1.15
            case .extraExtraLarge: 1.25
            case .extraExtraExtraLarge: 1.33
            case .accessibilityMedium: 1.52
            case .accessibilityLarge: 1.8
            case .accessibilityExtraLarge: 2.0
            case .accessibilityExtraExtraLarge: 2.2
            case .accessibilityExtraExtraExtraLarge: 2.5
            default: 1.0
        }
    }
}
