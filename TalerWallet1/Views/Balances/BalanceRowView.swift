/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

let SPACING = CGFloat(10)                  // space between the two buttons

struct BalanceLabel: View {
    let balanceTitle: String
    let horizontal: Bool
    let amountStr: String
    let iconOnly: Bool

    var body: some View {
        Group {         // can either be horizontal (preferred) or vertical (if doesn't fit horizontally)
            if !iconOnly {
                Text(balanceTitle)
                    .accessibilityFont(.title2)
                    .foregroundColor(.secondary)
            }
            if horizontal {
                Spacer(minLength: 0)
                Text(amountStr)
                    .accessibilityFont(.title)
                    .monospacedDigit()
            } else { HStack {
                Spacer(minLength: 0)
                Text(amountStr)
                    .accessibilityFont(.title)
                    .monospacedDigit()
            } }
        }
    }
}

struct BalanceButton: View {
    let amountStr: String
    let rowAction: () -> Void

    @AppStorage("iconOnly") var iconOnly: Bool = false

    var body: some View {
        let balanceTitle = String(localized: "Balance:", comment: "Main view")
        Button(action: rowAction) {
            SingleAxisGeometryReader { width in
                Group {
                    let balancesFont = TalerFont.uiFont(.title2)
                    let amountFont = TalerFont.uiFont(.title)
                    let titles = [(balanceTitle, balancesFont),
                                  (amountStr, amountFont)]
                    let needVStack = !iconOnly && Self.needVStack(titles, width: width, spacing: SPACING, sameSize: false)
                    if needVStack {
                        VStack(alignment: .leading, spacing: 0) {
                            BalanceLabel(balanceTitle: balanceTitle, horizontal: false, amountStr: amountStr, iconOnly: iconOnly)
                        }
                    } else {
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            BalanceLabel(balanceTitle: balanceTitle, horizontal: true, amountStr: amountStr, iconOnly: iconOnly)
                        }
                    }
                }
            }
        }   .disabled(false)
            .buttonStyle(TalerButtonStyle(type: iconOnly ? .plain : .balance, aligned: .trailing))
            .accessibilityElement(children: /*@START_MENU_TOKEN@*/.ignore/*@END_MENU_TOKEN@*/)
            .accessibilityLabel("\(balanceTitle) \(amountStr)")    // TODO: CurrencyFormatter!
    }
}


/// This view shows the currency row in a currency section
/// [Send Coins]  [Receive Coins]     Balance
struct BalanceRowView: View {
    let amount: Amount
    let currencyInfo: CurrencyInfo?
    let sendAction: () -> Void
    let recvAction: () -> Void
    let rowAction: () -> Void
    @Environment(\.sizeCategory) var sizeCategory
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let sendTitle1 = String(localized: "Send", comment: "Top of button <Send Money>")
    let sendTitle2 = String(localized: "Money", comment: "Bottom of button <Send Money>")
    let requestTitle1 = String(localized: "Request", comment: "Top of button <Request Payment>")
    let requestTitle2 = String(localized: "Payment", comment: "Bottom of button <Request Payment>")

    var body: some View {

        SingleAxisGeometryReader { width in
            VStack (alignment: .trailing) {
                let amountStr = currencyInfo?.string(for: amount.value)
                BalanceButton(amountStr: amountStr ?? amount.valueStr,
                              rowAction: rowAction)
                let uiFont = TalerFont.uiFont(.title3)
                let titles = [(requestTitle1, uiFont), (requestTitle2, uiFont), (sendTitle1, uiFont), (sendTitle2, uiFont)]
                let sendTitle = sendTitle1 + "\n" + sendTitle2
                let requestTitle = requestTitle1 + "\n" + requestTitle2
                let twoRowButtons = TwoRowButtons(sendTitle: sendTitle, recvTitle: requestTitle,
                                                  lineLimit: 5, sendDisabled: amount.isZero,
                                                  sendAction: sendAction, recvAction: recvAction)
//  let _ = print("Screenwidth: \(UIScreen.screenWidth)  Geometry: \(width)  \(sizeCategory): \(sizeCategory)")
                if Self.needVStack(titles, width: width, spacing: SPACING) {
                    VStack { twoRowButtons }
                } else {
                    HStack(spacing: SPACING) { twoRowButtons }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
// MARK: -
#if false // DEBUG
struct BalanceRowView_Previews: PreviewProvider {
    static var previews: some View {
        let test = try! Amount(fromString: TESTCURRENCY + ":1.23")
        let demo = try! Amount(fromString: DEMOCURRENCY + ":1234.56")
        List {
            Section {
                HStack(alignment: .lastTextBaseline) {
                    BalanceLabel(balanceTitle: "BalanceA:", horizontal: true, amountStr: test.valueStr, iconOnly: false)
                        .listRowSeparator(.hidden)
                }
            }
            Section {
                BalanceLabel(balanceTitle: "Balance:", horizontal: false, amountStr: demo.valueStr, iconOnly: false)
                    .listRowSeparator(.hidden)
            }
            Section {
                BalanceButton(amountStr: demo.valueStr, rowAction: {})
                    .listRowSeparator(.hidden)
            }
            Section {
                BalanceRowView(amount: demo, sendAction: {}, recvAction: {}, rowAction: {})
            }
            BalanceRowView(amount: test, sendAction: {}, recvAction: {}, rowAction: {})
        }
    }
}
#endif
