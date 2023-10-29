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
                              width: CGFloat,                   // total width available
                       sizeCategory: ContentSizeCategory,
                            spacing: CGFloat = HSPACING,        // between titles
                            padding: CGFloat = 20,
                           sameSize: Bool = true,
                           numViews: Int = 2)
    -> Bool {
        let correctForSize = correctForSize(sizeCategory)
//        let padding = 20.0        // TODO: depend on myListStyle
        let totalSpacing = spacing * CGFloat(numViews - 1)
        var totalWidth = padding + totalSpacing

        var maxTitleWidth = 0.0
        var minTitleWidth = 1000.0
        for (title, uiFont) in titles {
            let titleWidth = title.widthOfString(usingUIFont: uiFont)
  if width > 20 {
      let widthStr = String(format: "%.2f * %.2f = %.2f", titleWidth, correctForSize, titleWidth * correctForSize)
      print("❗️  \(title)  \(widthStr)")
  }
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
            let availableWidth = width - totalSpacing
            let singleWidth = availableWidth / CGFloat(numViews)
            let neededWidth = padding + maxTitleWidth
            if width > 20 {
                let width1Str = String(format: "%.2f -spacing %.2f = %.2f / %d = %.2f", width, totalSpacing,
                                       availableWidth, numViews, singleWidth)
                let width2Str = String(format: "%.2f +padding %.2f = %.2f", maxTitleWidth, padding, maxTitleWidth + padding)
                print("❗️ available: \(width1Str)   needed: \(width2Str)")
            }
            return neededWidth > singleWidth
        } else {
            if width > 20 {
                let totalStr = String(format: "%.2f -spacing %.2f = %.2f -padding %.2f = %.2f", totalWidth, totalSpacing,
                                      totalWidth - totalSpacing, padding, totalWidth - totalSpacing - padding)
                print("❗️ view width: \(width)   total: \(totalStr)")
//                let (amount, font) = titles[1]
//                print("❗️ view width: \(width)   total: \(totalStr)  min: \(minTitleWidth)  max: \(maxTitleWidth)  \(amount)")
            }
            return totalWidth > width
        }
    }

    static func correctForSize(_ sizeCategory: ContentSizeCategory) -> CGFloat {
        let corrValue = switch sizeCategory {
            case .extraSmall: 0.7
            case .small: 0.8
            case .medium: 0.9
//            case .large: 1.0
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
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // empirical values
            return corrValue
        } else {
            // preview doesn't use ContentSizeCategory for widthOfString(usingUIFont)
            // thus the empirical values are the square of what's really needed
            return sqrt(corrValue)
        }
    }
}
