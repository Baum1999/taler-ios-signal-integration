/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct InOrOutView: View {
    let title: (String, String)
    let horizontal: Bool
    let incoming: Bool
    let imageName: String

    public static func width(image1: String, title1: String, title2: String) -> CGFloat {
        let imageFont = TalerFont.uiFont(.largeTitle)
        let uiFont = TalerFont.uiFont(.body)

        let image2 = "++"
        let imageWidth = image2.widthOfString(usingUIFont: imageFont) + 8.0     //.padding(.trailing)
        let title1Width = title1.widthOfString(usingUIFont: uiFont)
        let title2Width = title2.widthOfString(usingUIFont: uiFont)
//    print("image: ", imageWidth, " title: ", max(title1Width, title2Width))
        return imageWidth + max(title1Width, title2Width)
    }

    var body: some View {
        let (title1, title2) = title
        HStack(spacing: 0) {
            let pendingColor = WalletColors().pendingColor(incoming)
            Image(systemName: imageName)
                .foregroundColor(pendingColor)
                .accessibilityFont(.largeTitle)
                .accessibility(hidden: true)
//                .padding(.trailing)
            Text(horizontal ? (title1 + "\n" + title2)
                            : (title1 + " " + title2))
                .lineLimit(2)
                .accessibilityFont(.body)
        }
    }
}

struct PendingAmountView: View {
    let amount: Amount
    let currencyInfo: CurrencyInfo?
    let incoming: Bool

    public static func amountStr(amount: Amount, currencyInfo: CurrencyInfo?, incoming: Bool) -> String {
        let sign = incoming ? "+ " : "- "
        let amountStr = currencyInfo?.string(for: amount.valueAsTuple)
        return sign + (amountStr ?? amount.valueStr)
    }
    
    public static func width(amount: Amount, currencyInfo: CurrencyInfo?, incoming: Bool) -> CGFloat {
        let valueStr = Self.amountStr(amount: amount, currencyInfo: currencyInfo, incoming: incoming)
        let uiFont = TalerFont.uiFont(.title)
        let width = valueStr.widthOfString(usingUIFont: uiFont)
//    print("Amount width: ", width)
        return width
    }

    var body: some View {
        let pendingColor = WalletColors().pendingColor(incoming)
        let valueStr = Self.amountStr(amount: amount, currencyInfo: currencyInfo, incoming: incoming)
        Text(valueStr)
            .foregroundColor(pendingColor)
            .accessibilityFont(.title)
            .monospacedDigit()
    }
}

struct PendingLabel: View {
    let amount: Amount
    let currencyInfo: CurrencyInfo?
    let incoming: Bool
    let horizontal: Bool        // true: HStack{ image + pending Xcoming + amount }
    let title: (String, String)
    let imageName: String

    var body: some View {
        Group {         // can either be horizontal (preferred) or vertical (if doesn't fit horizontally)
            InOrOutView(title: title, horizontal: horizontal, incoming: incoming, imageName: imageName)
            if horizontal {     // Group is an HStack already => just add Spacer + Amount
                Spacer(minLength: 0)
                PendingAmountView(amount: amount, currencyInfo: currencyInfo, incoming: incoming)
            } else {            // Group is a VStack => need HStack + Spacer to shift Amount to the trailing edge
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    PendingAmountView(amount: amount, currencyInfo: currencyInfo, incoming: incoming)
}   }   }   }   }

/// This view shows a pending transaction row in a currency section
struct PendingRowView: View {
    let amount: Amount
    let currencyInfo: CurrencyInfo?
    let incoming: Bool

    let inTitle1 = String(localized: "pending", comment: "Top of line <pending incoming>")
    let inTitle2 = String(localized: "incoming", comment: "Bottom of line <pending incoming>")
    let outTitle1 = String(localized: "pending", comment: "Top of line <pending outgoing>")
    let outTitle2 = String(localized: "outgoing", comment: "Bottom of line <pending outgoing>")

    func needVStack(available: CGFloat, inOrOutWidth: CGFloat, valueWidth: CGFloat) -> Bool {
        available < (inOrOutWidth + valueWidth + 40)
    }

    var body: some View {
        let imageName = incoming ? "text.badge.plus"
                                 : "text.badge.minus"
        let imageStr = String("\(Image(systemName: imageName))")
        SingleAxisGeometryReader { width in
            Group {
                let title = incoming ? (inTitle1, inTitle2)
                                     : (outTitle1, outTitle2)
                let inOrOutWidth = InOrOutView.width(image1: imageStr,
                                                     title1: incoming ? inTitle1 : outTitle1,
                                                     title2: incoming ? inTitle2 : outTitle2)
                let valueWidth = PendingAmountView.width(amount: amount,
                                                   currencyInfo: currencyInfo,
                                                       incoming: incoming)
//    let _ = print(width, " - ", inOrOutWidth + valueWidth, " = ", width - (inOrOutWidth + valueWidth))
                if needVStack(available: width, inOrOutWidth: inOrOutWidth, valueWidth: valueWidth) {
                    VStack(alignment: .leading, spacing: 0) {
                        PendingLabel(amount: amount, currencyInfo: currencyInfo,
                                   incoming: incoming, horizontal: false,
                                      title: title,     imageName: imageName)
                    }
                } else {
                    HStack(spacing: 0) {
                        PendingLabel(amount: amount, currencyInfo: currencyInfo,
                                   incoming: incoming, horizontal: true,
                                      title: title,     imageName: imageName)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
// MARK: -
#if DEBUG

func PreviewCurrencyInfo(_ currency: String, digits: Int) -> CurrencyInfo {
    let unitName = digits == 0 ? "¥" : "€"
    let scope = ScopeInfo(type: .global, currency: currency)
    let specs = CurrencySpecification(name: TESTCURRENCY,
//                        decimalSeparator: ".", groupSeparator: "'",
                     fractionalInputDigits: digits,
                    fractionalNormalDigits: digits,
              fractionalTrailingZeroDigits: digits,
//                   isCurrencyNameLeading: true,
                              altUnitNames: [0 : unitName])
    let formatter = CurrencyFormatter.formatter(scope: scope, specs: specs)
    return CurrencyInfo(scope: scope, specs: specs, formatter: formatter)
}

struct PendingRowView_Previews: PreviewProvider {
    static var previews: some View {
        let testInfo = PreviewCurrencyInfo(TESTCURRENCY, digits: 0)
        let demoInfo = PreviewCurrencyInfo(TESTCURRENCY, digits: 2)
        let test = try! Amount(fromString: TESTCURRENCY + ":1.23")
        let demo = try! Amount(fromString: DEMOCURRENCY + ":1234.56")
        List {
            PendingRowView(amount: test, currencyInfo: testInfo, incoming: true)
            PendingRowView(amount: demo, currencyInfo: demoInfo, incoming: false)
        }
    }
}
#endif
