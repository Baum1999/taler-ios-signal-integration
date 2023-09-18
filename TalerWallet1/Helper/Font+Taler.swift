/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI

// Use enums for multiple font types and functions for the set custom font.

fileprivate let ATKINSON    = "AtkinsonHyperlegible-"
fileprivate let NUNITO      = "Nunito-"

fileprivate let REGULAR     = "Regular"
fileprivate let BOLD        = "Bold"
fileprivate let BLACK       = "Black"
fileprivate let BLACKITALIC = "BlackItalic"
fileprivate let BOLDITALIC  = "BoldItalic"
fileprivate let ITALIC      = "Italic"

struct TalerFont {
    static var atkinson: Font {
        Font.custom(ATKINSON + REGULAR, size: 24, relativeTo: .title2)
    }
    static var nunito: Font {
        Font.custom(NUNITO + REGULAR, size: 24, relativeTo: .title2)
    }
    static var nunitoItalic: Font {
        Font.custom(NUNITO + ITALIC, size: 24, relativeTo: .title2)
    }

    static func atkinson(size: CGFloat, relativeTo style: UIFont.TextStyle) -> UIFont {
        if let font = UIFont(name: ATKINSON + REGULAR, size: size) {
            let fontMetrics = UIFontMetrics(forTextStyle: style)
            return fontMetrics.scaledFont(for: font)
        } else {
            return UIFont.preferredFont(forTextStyle: style)
        }
    }
    static func nunito(size: CGFloat, relativeTo: UIFont.TextStyle) -> UIFont {
        if let font = UIFont(name: NUNITO + REGULAR, size: size) {
            let fontMetrics = UIFontMetrics(forTextStyle: relativeTo)
            return fontMetrics.scaledFont(for: font)
        } else {
            return UIFont.preferredFont(forTextStyle: relativeTo)
        }
    }
    static func nunitoItalic(size: CGFloat, relativeTo: UIFont.TextStyle) -> UIFont {
        if let font = UIFont(name: NUNITO + ITALIC, size: size) {
            let fontMetrics = UIFontMetrics(forTextStyle: relativeTo)
            return fontMetrics.scaledFont(for: font)
        } else {
            return UIFont.preferredFont(forTextStyle: relativeTo)
        }
    }

    static func talerFont(_ talerFont: Int, size: CGFloat, relativeTo style: UIFont.TextStyle) -> UIFont {
        if talerFont != 0 {
            let uiFont: UIFont = (talerFont == 1) ? TalerFont.atkinson(size: size, relativeTo: style)
                               : (talerFont == 2) ? TalerFont.nunito(size: size, relativeTo: style)
                                                  : TalerFont.nunitoItalic(size: size, relativeTo: style)
            return uiFont
        } else {
            return UIFont.preferredFont(forTextStyle: style)
        }
    }
}

struct AccessibleFont {
    var regular: Font
    var bold: Font
    static var talerFont: Int {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            3
        } else {
            Controller.shared.talerFont
        }
    }

    init(_ base: String, size: CGFloat, relativeTo: Font.TextStyle, isBold: Bool = false) {
        if AccessibleFont.talerFont == 0 {
            self.regular = .system(relativeTo)
            self.bold = .system(relativeTo).bold()      // why is this allowed here (iOS-15) ??? should give compiler error
                                                        // bold() for Font needs iOS-16
                                                        // Text has a function bold(), needs iOS-13, but that shouldn't matter here
        } else if isBold && AccessibleFont.talerFont >= 2 {
            // Nunito has Black Variants, but AtkinsonHyperlegible doesn't
            self.regular = Font.custom(base + (AccessibleFont.talerFont == 2 ? BOLD : BOLDITALIC), size: size, relativeTo: relativeTo)
            self.bold = Font.custom(base + (AccessibleFont.talerFont == 2 ? BLACK : BLACKITALIC), size: size, relativeTo: relativeTo)
        } else {
            self.regular = Font.custom(base + (AccessibleFont.talerFont > 2 ? ITALIC : REGULAR), size: size, relativeTo: relativeTo)
            self.bold = Font.custom(base + (AccessibleFont.talerFont > 2 ? BOLDITALIC : BOLD), size: size, relativeTo: relativeTo)
        }
    }

    init(regular: Font, bold: Font) {
        self.regular = regular
        self.bold = bold
    }

    func value(_ legibilityWeight: LegibilityWeight?) -> Font {
        switch legibilityWeight {
            case .bold:     // should increase Font.Weight by 2
                // ultraLight => light
                // thin => regular
                // light => medium
                // regular => semibold
                // medium => bold
                // semibold => heavy
                // bold => black
                return bold
            default:
                return regular
        }
    }
}

extension AccessibleFont {
    static var fontName: String {
        (talerFont == 1) ? ATKINSON
                         : NUNITO
    }

    static var largeTitle:  AccessibleFont { AccessibleFont(fontName, size: 38, relativeTo: .largeTitle) }  // 34 -> 38
    static var title:       AccessibleFont { AccessibleFont(fontName, size: 31, relativeTo: .title) }       // 28 -> 31
    static var title2:      AccessibleFont { AccessibleFont(fontName, size: 25, relativeTo: .title2) }      // 22 -> 25
    static var title3:      AccessibleFont { AccessibleFont(fontName, size: 23, relativeTo: .title3) }      // 20 -> 23
    static var headline:    AccessibleFont { AccessibleFont(fontName, size: 19, relativeTo: .headline, isBold: true) } // 17 bold -> 19 bold
    static var body:        AccessibleFont { AccessibleFont(fontName, size: 19, relativeTo: .body) }        // 17 -> 19
    static var callout:     AccessibleFont { AccessibleFont(fontName, size: 18, relativeTo: .callout) }     // 16 -> 18
    static var subheadline: AccessibleFont { AccessibleFont(fontName, size: 17, relativeTo: .subheadline) } // 15 -> 17
    static var footnote:    AccessibleFont { AccessibleFont(fontName, size: 15, relativeTo: .footnote) }    // 13 -> 15
    static var caption:     AccessibleFont { AccessibleFont(fontName, size: 13, relativeTo: .caption) }     // 12 -> 13
//    static var caption2:    AccessibleFont { AccessibleFont(fontName, size: 12, relativeTo: .caption2) }    // 11 -> 12
}

struct AccessibilityFontViewModifier: ViewModifier {
    @Environment(\.legibilityWeight) private var legibilityWeight

    var font: AccessibleFont

    func body(content: Content) -> some View {
        content.font(font.value(legibilityWeight))
    }
}

extension View {
    func accessibilityFont(_ font: AccessibleFont) -> some View {
        return self.modifier(AccessibilityFontViewModifier(font: font))
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
    let talerFont: Int

    static func setNavBarFonts(talerFont: Int) -> Void {
        let navBarAppearance = UINavigationBar.appearance()
        navBarAppearance.titleTextAttributes = nil
        navBarAppearance.largeTitleTextAttributes = nil
        if talerFont != 0 {
            navBarAppearance.titleTextAttributes = [.font: TalerFont.talerFont(talerFont, size: 24, relativeTo: .title2)]
            navBarAppearance.largeTitleTextAttributes = [.font: TalerFont.talerFont(talerFont, size: 38, relativeTo: .largeTitle)]
        }
    }

    init(_ talerFont: Int) {
        self.talerFont = talerFont
        TalerNavBar.setNavBarFonts(talerFont: talerFont)
    }

    func body(content: Content) -> some View {
        let _ = TalerNavBar.setNavBarFonts(talerFont: talerFont)
        content
    }

}

extension View {
    @MainActor func talerNavBar(talerFont: Int) -> some View {
        self.modifier(TalerNavBar(talerFont))
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
struct ContentViewFonts: View {
    //    let myWeight: Font.Weight
    var body: some View {
        VStack {
            HStack {
                Text("title a")
                Text("bold").bold()
            }
            .accessibilityFont(.title)
            .padding()

            HStack {
                Text("title2 a")
                Text("italic").italic()
                Text("bold").bold()
            }
            .accessibilityFont(.title2)
            .padding()
            Text("headline")
                .accessibilityFont(.headline)
                .padding(.top)
            Text("headline bold")
                .bold()
                .accessibilityFont(.headline)
                .padding(.bottom)
            Text("title2 bold italic")
                .bold()
                .italic()
                .accessibilityFont(.title2)
                .padding()
        }
    }
}

#Preview("Font View") {
    ContentViewFonts()
}
