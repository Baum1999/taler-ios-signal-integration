/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

struct ThreeAmountsSheet: View {    // should be in a separate file
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
    var common: TransactionCommon
    var topAbbrev: String
    var topTitle: String
    var bottomTitle: String?
    var bottomAbbrev: String?
    let baseURL: String?
    let noFees: Bool?                       // true if exchange charges no fees at all
    var feeIsNegative: Bool?                // show fee with minus (or plus) sign, or no sign if nil
    let large: Bool               // set to false for QR or IBAN
    let summary: String?
    let merchant: String?

#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    var body: some View {
        let raw = common.amountRaw
        let effective = common.amountEffective
        let fee = common.fee()
        let incoming = common.incoming()
        let pending = common.isPending
        let isDone = common.isDone
        let incomplete = !(isDone || pending)

        let defaultBottomTitle  = incoming ? (pending ? String(localized: "Pending amount to obtain:")
                                                      : String(localized: "Obtained amount:") )
                                           : (pending ? String(localized: "Amount to pay:")
                                                      : String(localized: "Paid amount:") )
        let defaultBottomAbbrev = incoming ? (pending ? String(localized: "Pending:", comment: "mini")
                                                      : String(localized: "Obtained:", comment: "mini") )
                                           : (pending ? String(localized: "Pay:", comment: "mini")
                                                      : String(localized: "Paid:", comment: "mini") )
        let majorLcl = common.txState.major.localizedState
        let txStateLcl = developerMode && pending ? (common.txState.minor?.localizedState ?? majorLcl)
                                                  : majorLcl
        ThreeAmountsSection(stack: stack.push(),
                     currencyInfo: $currencyInfo,
                         topTitle: topTitle,
                        topAbbrev: topAbbrev,
                        topAmount: raw,
                           noFees: noFees,
                              fee: fee,
                    feeIsNegative: feeIsNegative,
                      bottomTitle: bottomTitle ?? defaultBottomTitle,
                     bottomAbbrev: bottomAbbrev ?? defaultBottomAbbrev,
                     bottomAmount: incomplete ? nil : effective,
                            large: large,
                          pending: pending,
                         incoming: incoming,
                          baseURL: baseURL,
                       txStateLcl: txStateLcl,
                          summary: summary,
                         merchant: merchant)
    }
}
// MARK: -
struct ThreeAmountsSection: View {
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo
    var topTitle: String
    var topAbbrev: String
    var topAmount: Amount
    let noFees: Bool?                       // true if exchange charges no fees at all
    var fee: Amount?                        // nil = don't show fee line, zero = no fee for this tx
    var feeIsNegative: Bool?                // show fee with minus (or plus) sign, or no sign if nil
    var bottomTitle: String
    var bottomAbbrev: String
    var bottomAmount: Amount?               // nil = incomplete (aborted, timed out)
    let large: Bool
    let pending: Bool
    let incoming: Bool
    let baseURL: String?
    let txStateLcl: String?                 // localizedState
    let summary: String?
    let merchant: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
        let labelColor = WalletColors().labelColor
        let foreColor = pending ? WalletColors().pendingColor(incoming)
                                : WalletColors().transactionColor(incoming)
        let hasNoFees = noFees ?? false
        Section {
            if let summary {
                Text(summary)
                    .talerFont(.title3)
                    .lineLimit(4)
                    .padding(.bottom)
            }
            if let merchant {
                Text(merchant)
                    .talerFont(.title3)
                    .lineLimit(4)
                    .padding(.bottom)
            }
            AmountRowV(stack: stack.push(),
                currencyInfo: $currencyInfo,
                       title: minimalistic ? topAbbrev : topTitle,
                      amount: topAmount,
                  isNegative: nil,
                       color: labelColor,
                       large: false)
                .padding(.bottom, 4)
            if hasNoFees == false {
                if let fee {
                    let title = minimalistic ? String(localized: "Exchange fee (short):", defaultValue: "Fee:", comment: "short version")
                                             : String(localized: "Exchange fee (long):", defaultValue: "Fee:", comment: "long version")
                    AmountRowV(stack: stack.push(),
                        currencyInfo: $currencyInfo,
                               title: title,
                              amount: fee,
                          isNegative: fee.isZero ? nil : feeIsNegative,
                               color: labelColor,
                               large: false)
                    .padding(.bottom, 4)
                }
                if let bottomAmount {
                    AmountRowV(stack: stack.push(),
                        currencyInfo: $currencyInfo,
                               title: minimalistic ? bottomAbbrev : bottomTitle,
                              amount: bottomAmount,
                          isNegative: nil,
                               color: foreColor,
                               large: large)
                }
            }
            if let baseURL {
                VStack(alignment: .leading) {
                               // TODO: "Issued by" for withdrawals
                    Text(minimalistic ? "Payment provider:" : "Using payment service provider:")
                        .multilineTextAlignment(.leading)
                        .talerFont(.body)
                    Text(baseURL.trimURL)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.center)
                        .talerFont(large ? .title3 : .body)
//                        .fontWeight(large ? .medium : .regular)  // @available(iOS 16.0, *)
                        .foregroundColor(labelColor)
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowSeparator(.hidden)
                .accessibilityElement(children: .combine)
            }
        } header: {
            if !minimalistic {
                Text("Summary")
                    .talerFont(.title3)
                    .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
            }
        }
    }
}
// MARK: -
#if  DEBUG
struct ThreeAmounts_Previews: PreviewProvider {
    @MainActor
    struct StateContainer: View {
        @State private var currencyInfoD: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
        @State private var currencyInfoT: CurrencyInfo = CurrencyInfo.zero(TESTCURRENCY)

        var body: some View {
            let common = TransactionCommon(type: .withdrawal,
                                        txState: TransactionState(major: .done),
                                amountEffective: Amount(currency: LONGCURRENCY, cent: 10),
                                      amountRaw: Amount(currency: LONGCURRENCY, cent: 20),
                                  transactionId: "someTxID",
                                      timestamp: Timestamp(from: 1_666_666_000_000),
                                      txActions: [])
//            let test = Amount(currency: TESTCURRENCY, cent: 123)
//            let demo = Amount(currency: DEMOCURRENCY, cent: 123456)

            List {
                ThreeAmountsSheet(stack: CallStack("Preview"),
                           currencyInfo: $currencyInfoD,
                                 common: common, topAbbrev: "Withdrawal",
                               topTitle: "Withdrawal", baseURL: DEMOEXCHANGE, noFees: false,
                                  large: 1==0, summary: nil, merchant: nil)
                .safeAreaInset(edge: .bottom) {
                    Button(String(localized: "Accept"), action: {})
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                        .disabled(true)
                }
            }
        }
    }

    static var previews: some View {
        StateContainer()
        //            .environment(\.sizeCategory, .extraExtraLarge)    Canvas Device Settings
    }
}
#endif
