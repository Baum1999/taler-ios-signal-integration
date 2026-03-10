/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

// Use enums for multiple font types and functions for the set custom font.

fileprivate let ATKINSON    = "AtkinsonHyperlegibleNext-"
fileprivate let NUNITO      = "Nunito-"

fileprivate let REGULAR     = "Regular"
fileprivate let ITALIC      = "Italic"
fileprivate let BOLD        = "Bold"
fileprivate let BOLDITALIC  = "BoldItalic"
fileprivate let BLACK       = "Black"
fileprivate let BLACKITALIC = "BlackItalic"

public extension Font {
    static func logo(_ size: CGFloat, weight: UIFont.Weight) -> Font {
        let traits = [UIFontDescriptor.TraitKey.weight: weight] // regular, medium, semibold, bold
        let fontDescriptor = UIFontDescriptor(fontAttributes: [UIFontDescriptor.AttributeName.family: "Atkinson Hyperlegible Next"])
        let fontDescriptor2 = fontDescriptor.addingAttributes([UIFontDescriptor.AttributeName.traits: traits])
        return Font(UIFont(descriptor: fontDescriptor2, size: size))
    }
}

extension UIFont {
    /// scalable system font for style and weight (and italic)
    /// https://stackoverflow.com/users/2145198/beebcon
    static func preferredFont(for style: TextStyle, weight: Weight, italic: Bool = false) -> UIFont {
        @Environment(\.sizeCategory) var sizeCategory

        // Get the style's default pointSize
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: traits)

        // Get the font at the default size and preferred weight
        var font = UIFont.systemFont(ofSize: desc.pointSize, weight: weight)
        if italic == true {
            font = font.with([.traitItalic])
        }

        // Setup the font to be auto-scalable
        let metrics = UIFontMetrics(forTextStyle: style)
        return metrics.scaledFont(for: font)
    }

    private func with(_ traits: UIFontDescriptor.SymbolicTraits...) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits).union(fontDescriptor.symbolicTraits)) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
// Use it like this:
//    UIFont.preferredFont(for: .largeTitle, weight: .regular)
//    UIFont.preferredFont(for: .headline, weight: .semibold, italic: true)



/// provides a (custom) scalable UIFont based on the first parameter: 0 = system, 1 = Atkinson, 2 = Nunito, 3 = NunitoItalic
struct TalerUIFont {
    @Environment(\.legibilityWeight) private var legibilityWeight: LegibilityWeight?

    private static func scalableSystemFont(for style: UIFont.TextStyle, legibilityBold: Bool = false,
                                           bold: Bool = false, italic: Bool = false) -> UIFont {
        let black = bold && legibilityBold
        return UIFont.preferredFont(for: style,
                                 weight: black ? .heavy
                                               : (bold || legibilityBold) ? .semibold : .regular,
                                 italic: italic)
    }

    /// check wether a custom font for fontName is available
    /// fontName already contains "Bold" (instead of "Regular") - the bold and italic params are only for the fallback
    private static func scalableUIFont(_ fontName: String, size: CGFloat, relativeTo style: UIFont.TextStyle,
                                       legibilityBold: Bool = false, bold: Bool = false, italic: Bool = false) -> UIFont {
        @Environment(\.sizeCategory) var sizeCategory
        if let font = UIFont(name: fontName, size: size) {
            // return a scalable UIFont
            let fontMetrics = UIFontMetrics(forTextStyle: style)
            return fontMetrics.scaledFont(for: font)
        } else {
            // fallback: return the system font
            return scalableSystemFont(for: style, legibilityBold: legibilityBold, bold: bold, italic: italic)
        }
    }

    private static func atkinson(size: CGFloat, relativeTo style: UIFont.TextStyle,
                                 legibilityBold: Bool = false, bold: Bool = false, italic: Bool = false) -> UIFont {
        let useBold = bold || legibilityBold
        let fontName = ATKINSON + (italic ? (useBold ? BOLDITALIC : ITALIC)
                                          : (useBold ? BOLD : REGULAR))
        return scalableUIFont(fontName, size: size, relativeTo: style,
                              legibilityBold: legibilityBold, bold: bold, italic: italic)
    }

    private static func nunito(size: CGFloat, relativeTo style: UIFont.TextStyle,
                               legibilityBold: Bool = false, bold: Bool = false, italic: Bool = false) -> UIFont {
        let black = bold && legibilityBold
        let fontName = NUNITO + (italic ? (black ? BLACKITALIC
                                                 : (bold || legibilityBold) ? BOLDITALIC : ITALIC)
                                        : (black ? BLACK
                                                 : (bold || legibilityBold) ? BOLD : REGULAR))
        return scalableUIFont(fontName, size: size, relativeTo: style,
                              legibilityBold: legibilityBold, bold: bold, italic: italic)
    }

    static func uiFont(_ selectedFont: Int, size: CGFloat, relativeTo style: UIFont.TextStyle,
                legibilityBold: Bool = false, bold: Bool = false, italic: Bool = false) -> UIFont {
        switch selectedFont {
            case 1: return TalerUIFont.atkinson(size: size, relativeTo: style,
                                              legibilityBold: legibilityBold, bold: bold, italic: italic)
            case 2: return TalerUIFont.nunito(size: size, relativeTo: style,
                                            legibilityBold: legibilityBold, bold: bold, italic: italic)
            default:
//                return UIFont.preferredFont(forTextStyle: style)
                return TalerUIFont.scalableSystemFont(for: style, legibilityBold: legibilityBold, bold: bold, italic: italic)
        }
    }

    static func uiFont(_ styleSize: StyleSizeBold) -> UIFont {
        return uiFont(Controller.shared.talerFontIndex, size: styleSize.size, relativeTo: styleSize.style)
    }
}

struct TalerFont {   // old running
    var regular: Font
    var bold: Font
    static var talerFontIndex: Int { return 2 }

    init(_ base: String, size: CGFloat, relativeTo: Font.TextStyle, isBold: Bool = false) {
        if TalerFont.talerFontIndex == 0 {
            self.regular = .system(relativeTo)
            self.bold = .system(relativeTo).bold()
        } else if isBold {
            // Nunito has Black Variants, but AtkinsonHyperlegible doesn't
            self.regular = Font.custom(base + (TalerFont.talerFontIndex == 2 ? BOLD : BOLDITALIC), size: size, relativeTo: relativeTo)
            self.bold = Font.custom(base + (TalerFont.talerFontIndex == 2 ? BLACK : BLACKITALIC), size: size, relativeTo: relativeTo)
        } else {
            self.regular = Font.custom(base + (TalerFont.talerFontIndex > 2 ? ITALIC : REGULAR), size: size, relativeTo: relativeTo)
            self.bold = Font.custom(base + (TalerFont.talerFontIndex > 2 ? BOLDITALIC : BOLD), size: size, relativeTo: relativeTo)
        }
    }

    init(regular: Font, bold: Font) {
        self.regular = regular
        self.bold = bold
    }

    func value(_ legibilityWeight: LegibilityWeight?) -> Font {
        switch legibilityWeight {
            case .bold: return bold
            default:    return regular
        }
    }
}

struct StyleSizeBold {
    let style: UIFont.TextStyle
    let size: CGFloat
    let bold: Bool
    let italic: Bool = false

    static var largeTitle:  StyleSizeBold { StyleSizeBold(style: .largeTitle, size: 34, bold: false) }      // 34 -> 38
    static var title:       StyleSizeBold { StyleSizeBold(style: .title1, size: 28, bold: false) }          // 28 -> 31
    static var title2:      StyleSizeBold { StyleSizeBold(style: .title2, size: 22, bold: false) }          // 22 -> 25
    static var title3:      StyleSizeBold { StyleSizeBold(style: .title3, size: 20, bold: false) }          // 20 -> 23
    static var headline:    StyleSizeBold { StyleSizeBold(style: .headline, size: 17, bold: true) }         // 17 bold -> 19 bold
    static var body:        StyleSizeBold { StyleSizeBold(style: .body, size: 17, bold: false) }            // 17 -> 19
    static var callout:     StyleSizeBold { StyleSizeBold(style: .callout, size: 16, bold: false) }         // 16 -> 18
    static var subheadline: StyleSizeBold { StyleSizeBold(style: .subheadline, size: 15, bold: false) }     // 15 -> 17
    static var footnote:    StyleSizeBold { StyleSizeBold(style: .footnote, size: 13, bold: false) }        // 13 -> 15
    static var caption:     StyleSizeBold { StyleSizeBold(style: .caption1, size: 12, bold: false) }        // 12 -> 13
//    static var caption2:    AccessibleFont { AccessibleFont(fontName, size: 11, relativeTo: .caption2) }    // 11 -> 12
}

extension TalerFont {   // old running
    static var fontName: String { NUNITO }

    static var largeTitle:  TalerFont { TalerFont(fontName, size: 34, relativeTo: .largeTitle) }  // 34 -> 38
    static var title:       TalerFont { TalerFont(fontName, size: 28, relativeTo: .title) }       // 28 -> 31
    static var title1:      TalerFont { TalerFont(fontName, size: 24, relativeTo: .title2) }      // Destructive Buttons
    static var title2:      TalerFont { TalerFont(fontName, size: 22, relativeTo: .title2) }      // 22 -> 25
    static var title3:      TalerFont { TalerFont(fontName, size: 20, relativeTo: .title3) }      // 20 -> 23
    static var picker:      TalerFont { TalerFont(fontName, size: 18, relativeTo: .body) }        // picker uses a different size!
    static var headline:    TalerFont { TalerFont(fontName, size: 17, relativeTo: .headline, isBold: true) } // 17 bold -> 19 bold
    static var body:        TalerFont { TalerFont(fontName, size: 17, relativeTo: .body) }        // 17 -> 19
    static var callout:     TalerFont { TalerFont(fontName, size: 16, relativeTo: .callout) }     // 16 -> 18
    static var subheadline: TalerFont { TalerFont(fontName, size: 15, relativeTo: .subheadline) } // 15 -> 17
    static var table:       TalerFont { TalerFont(fontName, size: 14, relativeTo: .subheadline) } // tableview uses a different size!
    static var footnote:    TalerFont { TalerFont(fontName, size: 13, relativeTo: .footnote) }    // 13 -> 15
    static var caption:     TalerFont { TalerFont(fontName, size: 12, relativeTo: .caption) }     // 12 -> 13
    static var badge:       TalerFont { TalerFont(fontName, size: 10, relativeTo: .caption) }     // 12 -> 13
}

struct StyleSizeBoldViewModifier: ViewModifier {
    @Environment(\.legibilityWeight) private var legibilityWeight
    var legibilityBold: Bool { legibilityWeight == .bold }

    let styleSize: StyleSizeBold

    static var talerFontIndex: Int {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return 2
        } else {
            return Controller.shared.talerFontIndex
        }
    }

    func body(content: Content) -> some View {      // TODO: italic
        let uiFont = TalerUIFont.uiFont(Self.talerFontIndex, size: styleSize.size, relativeTo: styleSize.style,
                                      legibilityBold: legibilityBold, bold: styleSize.bold)
        content.font(Font(uiFont))
    }
}

struct TalerFontViewModifier2: ViewModifier {   // old running
    @Environment(\.legibilityWeight) private var legibilityWeight

    var font: TalerFont

    func body(content: Content) -> some View {
        content.font(font.value(legibilityWeight))
    }
}

extension View {
    func talerFont(_ font: TalerFont) -> some View {
        return self.modifier(TalerFontViewModifier2(font: font))
    }
    func talerFont1(_ styleSize: StyleSizeBold) -> some View {
        return self.modifier(StyleSizeBoldViewModifier(styleSize: styleSize))
    }
}
// MARK: -
/// This works on-the-fly to update NavigationTitles when you change the font
struct NavigationBarBuilder: UIViewControllerRepresentable {
    var build: (UINavigationController) -> Void = { _ in }

    func makeUIViewController(context: UIViewControllerRepresentableContext<NavigationBarBuilder>) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController,
                                           context: UIViewControllerRepresentableContext<NavigationBarBuilder>) {
        if let navigationController = uiViewController.navigationController {
            self.build(navigationController)
        }
    }
}

/// This works only once. Each following call does nothing - including (re-)setting to nil
@MainActor
struct TalerNavBar: ViewModifier {
    let talerFontIndex: Int

    static func setNavBarFonts(talerFontIndex: Int) -> Void {
        let navBarAppearance = UINavigationBar.appearance()
        navBarAppearance.titleTextAttributes = nil
        navBarAppearance.largeTitleTextAttributes = nil
        if talerFontIndex != 0 {
            navBarAppearance.titleTextAttributes = [.font: TalerUIFont.uiFont(talerFontIndex, size: 24, relativeTo: .title2)]
            navBarAppearance.largeTitleTextAttributes = [.font: TalerUIFont.uiFont(talerFontIndex, size: 38, relativeTo: .largeTitle)]
        }
    }

    init(_ talerFontIdx: Int) {
        self.talerFontIndex = talerFontIdx
        TalerNavBar.setNavBarFonts(talerFontIndex: talerFontIdx)
    }

    func body(content: Content) -> some View {
        let _ = TalerNavBar.setNavBarFonts(talerFontIndex: talerFontIndex)
        content
    }

}

extension View {
    @MainActor func talerNavBar(talerFontIndex: Int) -> some View {
        self.modifier(TalerNavBar(talerFontIndex))
    }
}


#if false
//init() {
//    NavigationBarConfigurator.configureTitles()
//}
struct NavigationBarConfigurator {
    static func configureTitles() {
        let appearance = UINavigationBarAppearance()
        let design = UIFontDescriptor.SystemDesign.rounded
        if let descriptorWithDesign = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(design),
           let descriptorWithTraits = descriptorWithDesign.withSymbolicTraits(.traitBold) {
            let font = UIFont(descriptor: descriptorWithTraits, size: 34)
            appearance.largeTitleTextAttributes = [.font: font, .foregroundColor: UIColor.label]
        }
        if let smallTitleDescriptorWithDesign = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)                                                              .withDesign(design) {
            let smallTitleFont = UIFont(descriptor: smallTitleDescriptorWithDesign, size: 24)
            appearance.titleTextAttributes = [.font:smallTitleFont, .foregroundColor: UIColor.label]
        }
        UINavigationBar.appearance().standardAppearance = appearance
    }
}
#endif
// MARK: -
#if DEBUG
struct ContentViewFonts: View {
    //    let myWeight: Font.Weight
    var body: some View {
        VStack {
            HStack {
                Text(verbatim: "title a")
                Text(verbatim: "bold").bold()
            }
            .talerFont(.title)
            .padding()

            HStack {
                Text(verbatim: "title2 a")
                Text(verbatim: "italic").italic()
                Text(verbatim: "bold").bold()
            }
            .talerFont(.title2)
            .padding()
            Text(verbatim: "headline")
                .talerFont(.headline)
                .padding(.top)
            Text(verbatim: "headline bold")
                .bold()
                .talerFont(.headline)
                .padding(.bottom)
            Text(verbatim: "title2 bold italic")
                .bold()
                .italic()
                .talerFont(.title2)
                .padding()
        }
    }
}

#Preview("Font View") {
    ContentViewFonts()
}
#endif
