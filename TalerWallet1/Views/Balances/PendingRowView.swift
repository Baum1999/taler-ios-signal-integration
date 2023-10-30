/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct PendingRowContentV: View {
    let titles: (String, String?)
    let isHorizontal: Bool
    let incoming: Bool

    public static func width(titles: (String, String?), isHorizontal: Bool) -> CGFloat {
        let imageFont = TalerFont.uiFont(.largeTitle)
        let uiFont = TalerFont.uiFont(.body)

        let image = "++"
        let imageWidth = image.widthOfString(usingUIFont: imageFont) + 8.0     // spacing: 8
        let (title1, title2) = titles
        let title1Width = title1.widthOfString(usingUIFont: uiFont)
        var title2Width = 0.0
        var totalWidth = title1Width
        if let title2 {
            title2Width = title2.widthOfString(usingUIFont: uiFont)
            let totalStr = title1 + " " + title2
            totalWidth = totalStr.widthOfString(usingUIFont: uiFont)
        }

//    let logStr = String(format: "image: %.2f   title: %.2f   total: %.2f", imageWidth, max(title1Width, title2Width), totalWidth)
//    print(logStr)
        return imageWidth + (isHorizontal ? totalWidth
                                          : max(title1Width, title2Width))
    }

    var body: some View {
        let pendingColor = WalletColors().pendingColor(incoming)
        let imageName = incoming ? "plus.diamond"       //  goforward.plus   circle
                                 : "minus.diamond"      //
        HStack(spacing: 8) {
            Image(systemName: imageName)
                .foregroundColor(pendingColor)
                .accessibilityFont(.largeTitle)
                .accessibility(hidden: true)

            Text(title(titles, isHorizontal))
                .lineLimit(4)
                .accessibilityFont(.body)
        }
    }
}

/// This view shows a pending transaction row in a currency section
struct PendingRowView: View {
    let amount: Amount
    let currencyInfo: CurrencyInfo?
    let incoming: Bool

    @AppStorage("iconOnly") var iconOnly: Bool = false

    let inTitle0 = String(localized: "Incoming", comment: "Abbreviation <pending incoming>")
    let inTitle1 = String(localized: "Pending", comment: "Top of line <Pending incoming>")
    let inTitle2 = String(localized: "incoming", comment: "Bottom of line <pending incoming>")
    let outTitle0 = String(localized: "Outgoing", comment: "Abbreviation <pending outgoing>")
    let outTitle1 = String(localized: "Pending", comment: "Top of line <Pending outgoing>")
    let outTitle2 = String(localized: "outgoing", comment: "Bottom of line <pending outgoing>")

    func needVStack(available: CGFloat, contentWidth: CGFloat, valueWidth: CGFloat) -> Bool {
        available < (contentWidth + valueWidth + 40)
    }

    var body: some View {
        let pendingColor = WalletColors().pendingColor(incoming)
        SingleAxisGeometryReader { width in
            Group {
                let amountStr = amount.string(currencyInfo)
                let amountWidth = amountStr.width(largeAmountFont: false)
                let inTitle = iconOnly ? (inTitle0, nil)
                                       : (inTitle1, inTitle2)
                let outTitle = iconOnly ? (outTitle0, nil)
                                        : (outTitle1, outTitle2)
                let title = incoming ? inTitle
                                     : outTitle
                let contentWidth = PendingRowContentV.width(titles: incoming ? inTitle : outTitle,
                                                      isHorizontal: true)

                let needVStack = needVStack(available: width, contentWidth: contentWidth, valueWidth: amountWidth)
                AmountRowV(amountStr: amountStr, amountColor: pendingColor, largeAmountFont: false,
                           fitsHorizontal: !needVStack, vertAlignment: .center) {
                    // isHorizontal=true to try to fit "- Pending outgoing" + amount in 1 line
                    PendingRowContentV(titles: title, isHorizontal: true, incoming: incoming)
                }
            }
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
