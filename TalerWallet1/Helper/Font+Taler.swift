/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

// Use enums for multiple font types and functions for the set custom font.

fileprivate let ATKINSON   = "AtkinsonHyperlegible-"
fileprivate let NUNITO     = "Nunito-"

fileprivate let REGULAR    = "Regular"
fileprivate let BOLD       = "Bold"
fileprivate let BOLDITALIC = "BoldItalic"
fileprivate let ITALIC     = "Italic"

extension Font {
    enum TalerFont {
        case regular
        case bold
        case boldItalic
        case italic
        case custom(String)

        var value: String {
            switch self {
                case .regular: return REGULAR
                case .bold: return BOLD
                case .boldItalic: return BOLDITALIC
                case .italic: return ITALIC

                case .custom(let name):
                    return name
            }
        }
    }

    static func talerFont(_ type: TalerFont, size: CGFloat = 17) -> Font {
        return .custom(type.value, size: size)
    }

    static func talerFontName(_ index: Int) -> String {
        if index == 1 {
            return ATKINSON
        } else {
            return NUNITO
        }
    }

    static var talerLargeTitle: Font {
        Controller.shared.talerFont == 0 ? .largeTitle :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 38, relativeTo: .largeTitle)
    } // 34 -> 38
    static var talerTitle: Font {
        Controller.shared.talerFont == 0 ? .title :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 31, relativeTo: .title)
    } // 28 -> 31
    static var talerTitle2: Font {
        Controller.shared.talerFont == 0 ? .title2 :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 25, relativeTo: .title2)
    } // 22 -> 25
    static var talerTitle3: Font {
        Controller.shared.talerFont == 0 ? .title3 :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 23, relativeTo: .title3)
    } // 20 -> 23
    static var talerHeadline: Font {
        Controller.shared.talerFont == 0 ? .headline :
            .custom(talerFontName(Controller.shared.talerFont) + BOLD, size: 19, relativeTo: .headline)
    } // 17 bold -> 19 bold
    static var talerBody: Font {
        Controller.shared.talerFont == 0 ? .body :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 19, relativeTo: .body)
    } // 17 -> 19
    static var talerCallout: Font {
        Controller.shared.talerFont == 0 ? .callout :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 18, relativeTo: .callout)
    } // 16 -> 18
    static var talerSubheadline: Font {
        Controller.shared.talerFont == 0 ? .subheadline :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 17, relativeTo: .subheadline)
    } // 15 -> 17
    static var talerFootnote: Font {
        Controller.shared.talerFont == 0 ? .footnote :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 15, relativeTo: .footnote)
    } // 13 -> 15
    static var talerCaption: Font {
        Controller.shared.talerFont == 0 ? .caption :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 13, relativeTo: .caption)
    } // 12 -> 13
    static var talerCaption2: Font {
        Controller.shared.talerFont == 0 ? .caption2 :
            .custom(talerFontName(Controller.shared.talerFont) + REGULAR, size: 12, relativeTo: .caption2)
    } // 11 -> 12
}

struct ContentViewFonts: View {
    var body: some View {
        VStack {
            Text("Text demo")
                .font(.talerFont(.regular))
            Text("Text demo")
                .font(.talerFont(.italic))
            Text("Text demo")
                .font(.talerFont(.bold))
            Text("Text demo")
                .font(.talerFont(.boldItalic))

            Text("Text demo")
                .font(.talerBody)

        }
    }
}

#Preview("Font View") {
    ContentViewFonts()
}
