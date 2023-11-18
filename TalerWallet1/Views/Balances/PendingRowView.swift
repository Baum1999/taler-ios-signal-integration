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
    let shouldConfirm: Bool
    let needsKYC: Bool

    public static func width(titles: (String, String?), isHorizontal: Bool,
                             sizeCategory: ContentSizeCategory) -> CGFloat {
        let imageFont = TalerFont.uiFont(.largeTitle)
        let uiFont = TalerFont.uiFont(.body)

        let image = "++"
        let imageWidth = image.widthOfString(usingUIFont: imageFont, sizeCategory) + 8.0     // spacing: 8
        let (title1, title2) = titles
        let title1Width = title1.widthOfString(usingUIFont: uiFont, sizeCategory)
        var title2Width = 0.0
        var totalWidth = title1Width
        if let title2 {
            title2Width = title2.widthOfString(usingUIFont: uiFont, sizeCategory)
            let totalStr = title1 + " " + title2
            totalWidth = totalStr.widthOfString(usingUIFont: uiFont, sizeCategory)
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
        let badgeName = needsKYC ? "star.fill"
                                 : "circle.fill"
        HStack(spacing: 8) {
            HStack(alignment: .top, spacing: -8) {      // TODO: adapt spacing to dynamic fontsize
                Image(systemName: imageName)
                    .foregroundColor(pendingColor)
                    .accessibilityFont(.largeTitle)
                    .accessibility(hidden: true)
                Image(systemName: badgeName)
                    .accessibilityFont(.caption)
                    .foregroundColor((needsKYC || shouldConfirm) ? .red : .clear)
            }
            let pendingAccTitles = accessTitles(titles, isHorizontal)
            Text(pendingAccTitles.0)
                .accessibilityLabel(Text(pendingAccTitles.1))
                .lineLimit(4)
                .accessibilityFont(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(needsKYC ? ". Needs K Y C" :
                       shouldConfirm ? ". Needs bank confirmation" : EMPTYSTRING)
        .accessibilityHint("Will go to pending transaction list.")

    }
}

/// This view shows a pending transaction row in a currency section
struct PendingRowView: View {
    let amount: Amount
    let incoming: Bool
    let shouldConfirm: Bool
    let needsKYC: Bool

    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller
    @AppStorage("iconOnly") var iconOnly: Bool = false

    let inTitle0 = String(localized: "TitleIncoming_Short", defaultValue: "Incoming",
                            comment: "Abbreviation of `Pending incoming´ in Balances")
    let inTitle1 = String(localized: "TitleIncoming_Top", defaultValue: "Pending",
                            comment: "Top (first half) of line `Pending incoming´ in Balances")
    let inTitle2 = String(localized: "TitleIncoming_Bottom", defaultValue: "incoming",
                            comment: "Bottom (second half) of line `Pending incoming´ in Balances")
    let outTitle0 = String(localized: "TitleOutgoing_Short", defaultValue: "Outgoing",
                             comment: "Abbreviation of `Pending outgoing´ in Balances")
    let outTitle1 = String(localized: "TitleOutgoing_Top", defaultValue: "Pending",
                             comment: "Top (first half) of line `Pending outgoing´ in Balances")
    let outTitle2 = String(localized: "TitleOutgoing_Bottom", defaultValue: "outgoing",
                             comment: "Bottom (second half) of line `Pending outgoing´ in Balances")

    func needVStack(available: CGFloat, contentWidth: CGFloat, valueWidth: CGFloat) -> Bool {
        if available > 20 {
            let logStr = String(format: "available: %.2f   sum: %.2f = content: %.2f  + value: %.2f",
                                available, contentWidth + valueWidth, contentWidth, valueWidth)
            print(logStr)
        }
        return available < (contentWidth + valueWidth + 20)
    }

    var body: some View {
        let pendingColor = WalletColors().pendingColor(incoming)
        SingleAxisGeometryReader { width in
            Group {
                let currencyInfo = controller.info(for: amount.currencyStr, controller.currencyTicker)
                let amountStr = amount.string(currencyInfo)
                let amountWidth = amountStr.width(largeAmountFont: false, sizeCategory)
                let inTitles = iconOnly ? (inTitle0, nil)
                                        : (inTitle1, inTitle2)
                let outTitles = iconOnly ? (outTitle0, nil)
                                         : (outTitle1, outTitle2)
                let titles = incoming ? inTitles
                                      : outTitles
                let contentWidth = PendingRowContentV.width(titles: titles,
                                                      isHorizontal: false,
                                                      sizeCategory: sizeCategory)
                let needVStack = needVStack(available: width, contentWidth: contentWidth, valueWidth: amountWidth)
                AmountRowV(amountStr: amountStr, amountColor: pendingColor, largeAmountFont: false,
                           fitsHorizontal: !needVStack, vertAlignment: .center) {
                    // isHorizontal=true to try to fit "- Pending outgoing" + amount in 1 line
                    PendingRowContentV(titles: titles, isHorizontal: true, incoming: incoming,
                                       shouldConfirm: shouldConfirm, needsKYC: needsKYC)
                }
            }
        }
    }
}
// MARK: -
#if DEBUG
func PreviewCurrencyInfo(_ currency: String, digits: Int) -> CurrencyInfo {
    let unitName = digits == 0 ? "テ" : "ク"  // do not use real currency symbols like "¥" : "€"
    let scope = ScopeInfo(type: .global, currency: currency)
    let specs = CurrencySpecification(name: currency,
                     fractionalInputDigits: digits,
                    fractionalNormalDigits: digits,
              fractionalTrailingZeroDigits: digits,
                              altUnitNames: [0 : unitName])
    let previewFormatter = CurrencyFormatter.formatter(scope: scope, specs: specs)
    return CurrencyInfo(scope: scope, specs: specs, formatter: previewFormatter)
}

@MainActor
fileprivate struct Preview_Content: View {
    var body: some View {
        let test = Amount(currency: TESTCURRENCY, cent: 123)
        let demo = Amount(currency: DEMOCURRENCY, cent: 123456)
        List {
            PendingRowView(amount: test, incoming: true, shouldConfirm: true, needsKYC: false)
            PendingRowView(amount: demo, incoming: false, shouldConfirm: false, needsKYC: true)
        }
    }
}
fileprivate struct Previews: PreviewProvider {
    @MainActor
    struct StateContainer: View {
//        @StateObject private var controller = Controller.shared
        var body: some View {
            Text("Hello")
//            Preview_Content()
//                .environmentObject(controller)
        }
    }
    static var previews: some View {
        StateContainer()
    }
}
#endif
