/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct ThreeAmountsSheet: View {
    var common: TransactionCommon
    var topAbbrev: String
    var topTitle: String
    var bottomTitle: String?
    var bottomAbbrev: String?
    let baseURL: String?
    let large: Bool               // set to false for QR or IBAN
    let summary: String?

    var body: some View {
        let raw = common.amountRaw
        let effective = common.amountEffective
        let fee = common.fee()
        let incoming = common.incoming()
        let pending = (common.txState.major == .pending)
        let isDone = (common.txState.major == .done)
        let incomplete = !(isDone || pending)

        let defaultBottomTitle = incoming ? (pending ? String(localized: "Pending amount to obtain:")
                                                     : String(localized: "Obtained amount:") )
                                           : (pending ? String(localized: "Amount to pay:")
                                                      : String(localized: "Paid amount:") )
        let defaultBottomAbbrev = incoming ? (pending ? String(localized: "Pending:", comment: "mini")
                                                      : String(localized: "Obtained:", comment: "mini") )
                                           : (pending ? String(localized: "Pay:", comment: "mini")
                                                      : String(localized: "Paid:", comment: "mini") )
        ThreeAmountsV(topTitle: topTitle, topAbbrev: topAbbrev, topAmount: raw, fee: fee,
                   bottomTitle: bottomTitle ?? defaultBottomTitle,
                  bottomAbbrev: bottomAbbrev ?? defaultBottomAbbrev,
                  bottomAmount: incomplete ? nil : effective,
                         large: large, pending: pending, incoming: incoming,
                       baseURL: baseURL,
                        status: common.txState.major.localizedState,
                       summary: summary)
    }
}
// MARK: -
struct ThreeAmountsV: View {
    var topTitle: String
    var topAbbrev: String
    var topAmount: Amount
    var fee: Amount?
    var bottomTitle: String
    var bottomAbbrev: String
    var bottomAmount: Amount?
    let large: Bool
    let pending: Bool
    let incoming: Bool
    let baseURL: String?
    let status: String?
    let summary: String?

    @AppStorage("iconOnly") var iconOnly: Bool = false
    
    var body: some View {
        let labelColor = Color(UIColor.label)
        let foreColor = pending ? WalletColors().pendingColor(incoming)
                                : WalletColors().transactionColor(incoming)
        Section {
            if let summary {
                Text(summary)
                    .accessibilityFont(.title2)
                    .lineLimit(4)
                    .padding(.bottom)
            }
            AmountRowV(title: iconOnly ? topAbbrev : topTitle,
                      amount: topAmount,
                       color: labelColor,
                       large: large)
                .padding(.bottom, 4)
                .accessibilityElement(children: .combine)
            if let fee {
                AmountRowV(title: iconOnly ? String(localized: "Fee (short):", defaultValue:"Fee:", comment:"short version")
                                           : String(localized: "Fee (long):", defaultValue:"Fee:", comment:"long version"),
                          amount: fee,
                           color: labelColor,
                           large: false)
                .padding(.bottom, 4)
                .accessibilityElement(children: .combine)
            }
            if let bottomAmount {
                AmountRowV(title: iconOnly ? bottomAbbrev : bottomTitle,
                          amount: bottomAmount,
                           color: foreColor,
                           large: large)
                .accessibilityElement(children: .combine)
            }
            if let baseURL {
                VStack(alignment: .leading) {
                    Text(iconOnly ? "Payment Provider:" : "Using Payment Provider:")
                        .multilineTextAlignment(.leading)
                        .accessibilityFont(.body)
                    HStack {
                        Spacer()
                        Text(baseURL.trimURL())
                            .multilineTextAlignment(.center)
                            .accessibilityFont(large ? .title3 : .body)
//                          .fontWeight(large ? .medium : .regular)  // @available(iOS 16.0, *)
                            .foregroundColor(labelColor)
                    }
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowSeparator(.hidden)
                .accessibilityElement(children: .combine)
            }
        } header: {
            if !iconOnly {
                Text("Summary")
                    .accessibilityFont(.title3)
            }
        }
    }
}
// MARK: -
struct ThreeAmounts_Previews: PreviewProvider {
    static var previews: some View {
        let common = TransactionCommon(type: .withdrawal,
                                    txState: TransactionState(major: .done),
                            amountEffective: Amount(currency: LONGCURRENCY, cent: 10),
                                  amountRaw: Amount(currency: LONGCURRENCY, cent: 20),
                              transactionId: "someTxID",
                                  timestamp: Timestamp(from: 1_666_666_000_000),
                                  txActions: [])
        Group {
            List {
                ThreeAmountsSheet(common: common, topAbbrev: "Withdrawal",
                                topTitle: "Withdrawal", baseURL: DEMOEXCHANGE,
                                   large: 1==0, summary: nil)
                    .safeAreaInset(edge: .bottom) {
                        Button(String(localized: "Accept"), action: {})
                            .buttonStyle(TalerButtonStyle(type: .prominent))
                            .padding(.horizontal)
                            .disabled(true)
                    }
            }
        }
    }
}
