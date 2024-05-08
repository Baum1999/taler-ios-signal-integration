/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
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

    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
              let range = self[startIndex...]
            .range(of: string, options: options) {
            result.append(range)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
            index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}

extension String {
    func replacingOccurrences(of char1: String.Element, with char2: String.Element) -> String {
        String(self.map {
            $0 == char1 ? char2 : $0
        })
    }

    func nbs() -> String {
        self.replacingOccurrences(of: " ", with: NONBREAKING)
    }

    func tabbed(oneLine: Bool) -> String {
        let fragments = self.components(separatedBy: "\t")
        if fragments.count > 1 {
            let separator = oneLine ? " " : "\n"
            return fragments.joined(separator: separator)
        }
        return self
    }

    func widthOfString(usingUIFont font: UIFont) -> CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: font]
        let size = self.size(withAttributes: fontAttributes)
        return size.width
    }

    func widthOfString(usingUIFont font: UIFont, _ sizeCategory: ContentSizeCategory) -> CGFloat {
        let width = widthOfString(usingUIFont: font)
        let correctForSize = correctForSize(sizeCategory)
        return width * correctForSize
    }

    public func width(largeAmountFont: Bool, _ sizeCategory: ContentSizeCategory) -> CGFloat {
        let uiFont = TalerUIFont.uiFont(largeAmountFont ? .title : .title2)
        return widthOfString(usingUIFont: uiFont, sizeCategory)
    }

    // This would be used like so:
    // let uiFont = UIFont.systemFont(ofSize: 17, weight: .bold)
    // let width = "SomeString".widthOfString(usingUIFont: uiFont)

    ///
    fileprivate func correctForSize(_ sizeCategory: ContentSizeCategory) -> CGFloat {
        // empirical values
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
            // directly return the empirical value
            return corrValue
        } else {
            // preview doesn't use ContentSizeCategory for widthOfString(usingUIFont)
            // thus the empirical values are the square of what's really needed
            return sqrt(corrValue)
        }
    }
}
