/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct BalanceButton: View {
    let amountStr: String
    let sizeCategory: ContentSizeCategory
    let rowAction: () -> Void

    @AppStorage("iconOnly") var iconOnly: Bool = false
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
//    @AppStorage("moreContrast") var moreContrast: Bool = false

    var body: some View {
        let balanceTitleStr = String(localized: "Balance:", comment: "Main view")
        Button(action: rowAction) {
            SingleAxisGeometryReader { width in         // e.g. 301 instead of 313 => padding = 6
                Group {
                    let title = iconOnly ? "" : balanceTitleStr
                    let titles = [(balanceTitleStr, TalerFont.uiFont(.title2)),
                                  (amountStr,    TalerFont.uiFont(.title))]
                    let fitsSideBySide = iconOnly || Self.fitsSideBySide(titles, availableWidth: width,
                                                                  sizeCategory: sizeCategory,
                                                                  padding: 20, sameSize: false)
                    AmountRowV(amountStr: amountStr, amountColor: .primary, largeAmountFont: true,
                               fitsHorizontal: fitsSideBySide, vertAlignment: .lastTextBaseline) {
                        Text(title)
                            .accessibilityFont(.title2)
                            .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
//                            .foregroundColor(moreContrast ? .primary : .secondary)
                    }
                }
            }
        }   .disabled(false)
            .buttonStyle(TalerButtonStyle(type: iconOnly ? .plain : .balance, aligned: .trailing))
            .accessibilityElement(children: .combine)
            .accessibilityHint("Will go to main transactions list.")
//            .accessibilityLabel(balanceTitleStr + " " + amountStr)    // TODO: CurrencyFormatter!
    }
}


/// This view shows the currency row in a currency section, and two action buttons below
///  Balance:               amount
/// [Send Money]  [Request Payment]
struct BalanceRowView: View {
    let amount: Amount
    let currencyInfo: CurrencyInfo?
    let sendAction: () -> Void
    let recvAction: () -> Void
    let rowAction: () -> Void
    @Environment(\.sizeCategory) var sizeCategory
    @EnvironmentObject private var controller: Controller
    @AppStorage("iconOnly") var iconOnly: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let sendTitle0 = String(localized: "SendButton_Short", defaultValue: "Send",
                              comment: "Abbreviation of button `Send Money´")
    let sendTitle1 = String(localized: "SendButton_Top", defaultValue: "Send",
                              comment: "Top (first half) of button `Send Money´")
    let sendTitle2 = String(localized: "SendButton_Bottom", defaultValue: "Money",
                              comment: "Bottom (second half) of button `Send Money´")
    let requestTitle0 = String(localized: "RequestButton_Short", defaultValue: "Request",
                                 comment: "Abbreviation of button `Request Payment´")
    let requestTitle1 = String(localized: "RequestButton_Top", defaultValue: "Request",
                                 comment: "Top (first half) of button `Request Payment´")
    let requestTitle2 = String(localized: "RequestButton_Bottom", defaultValue: "Payment",
                                 comment: "Bottom (second half) of button `Request Payment´")

    var body: some View {
        SingleAxisGeometryReader { width in
            VStack (alignment: .trailing) {
                let currencyInfo = controller.info(for: amount.currencyStr, controller.currencyTicker)
                let amountStr = amount.string(currencyInfo)
                BalanceButton(amountStr: amountStr,
                           sizeCategory: sizeCategory,
                              rowAction: rowAction)
                let uiFont = TalerFont.uiFont(.title3)
                let titles = iconOnly ? [(sendTitle0, uiFont), (requestTitle0, uiFont)]
                           : [(sendTitle1, uiFont), (sendTitle2, uiFont), (requestTitle1, uiFont), (requestTitle2, uiFont)]
                let fitsSideBySide = Self.fitsSideBySide(titles, availableWidth: width, sizeCategory: sizeCategory, padding: 10)
                let twoRowButtons = TwoRowButtons(sendTitles: iconOnly ? (sendTitle0, nil) : (sendTitle1, sendTitle2),
                                                  recvTitles: iconOnly ? (requestTitle0, nil) : (requestTitle1, requestTitle2),
                                              fitsSideBySide: fitsSideBySide,
                                                   lineLimit: 5,
                                                sendDisabled: amount.isZero,
                                                  sendAction: sendAction,
                                                  recvAction: recvAction)
                if fitsSideBySide {
                    HStack(spacing: HSPACING) { twoRowButtons }
                } else {
                    VStack { twoRowButtons }
                }
            }
        }
    }
}
// MARK: -
#if  DEBUG

struct BalanceRowView_Previews: PreviewProvider {
  struct StateContainer: View {
    var body: some View {
        let testInfo = PreviewCurrencyInfo(TESTCURRENCY, digits: 0)
        let demoInfo = PreviewCurrencyInfo(TESTCURRENCY, digits: 2)
        let test = Amount(currency: TESTCURRENCY, cent: 123)
        let demo = Amount(currency: DEMOCURRENCY, cent: 123456)
//        let testStr = test.string(testInfo)
//        let demoStr = demo.string(demoInfo)

        List {
            Section {
                BalanceRowView(amount: demo, currencyInfo: demoInfo, sendAction: {}, recvAction: {}, rowAction: {})
            }
            BalanceRowView(amount: test, currencyInfo: testInfo, sendAction: {}, recvAction: {}, rowAction: {})
        }
    }
  }

    static var previews: some View {
        StateContainer()
//            .environment(\.sizeCategory, .extraExtraLarge)    Canvas Device Settings
    }
}
#endif
