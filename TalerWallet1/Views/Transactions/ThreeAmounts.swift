/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct ThreeAmounts: View {
    var common: TransactionCommon
    var topTitle: String
    var bottomTitle: String?
    let baseURL: String?
    let large: Bool               // set to false for QR or IBAN
    var body: some View {
        let raw = common.amountRaw
        let effective = common.amountEffective
        let fee = common.fee()
        let incoming = common.incoming()
        let pending = (common.txState.major == TransactionMajorState.pending)

        let defaultBottomTitle = incoming ? (pending ? "Pending coins to obtain:" : "Obtained coins:")
                                                     : "Paid coins:"
        ThreeAmountsView(topTitle: topTitle, topAmount: raw, fee: fee,
                      bottomTitle: bottomTitle ?? defaultBottomTitle, bottomAmount: effective,
                            large: large, pending: pending, incoming: incoming,
                          baseURL: baseURL,
                           status: common.txState.major.rawValue)
    }
}
// MARK: -
struct ThreeAmountsView: View {
    var topTitle: String
    var topAmount: Amount
    var fee: Amount
    var bottomTitle: String
    var bottomAmount: Amount
    let large: Bool
    let pending: Bool
    let incoming: Bool
    let baseURL: String?
    var status: String?

    var body: some View {
        let labelColor = Color(UIColor.label)
        let foreColor = pending ? WalletColors().pendingColor(incoming)
                                : WalletColors().transactionColor(incoming)
        let feeColor = WalletColors().transactionColor(false)
        let feeSign = incoming ? "-" : "+"

        VStack {
            AmountView(title: topTitle,
                       value: topAmount.readableDescription,
                       color: labelColor,
                       large: large)
                .padding(.bottom, 4)
            AmountView(title: "Exchange fee:",
                       value: feeSign + fee.readableDescription,
                       color: fee.isZero ? labelColor : feeColor,
                       large: false)
                .padding(.bottom, 4)
            AmountView(title: bottomTitle,
                       value: bottomAmount.readableDescription,
                       color: foreColor,
                       large: large)
            if let baseURL {
                VStack {
                    Text(incoming ? "from Exchange:" : "to Exchange:")
                        .font(.title3)
                    Text(baseURL.trimURL())
                        .font(large ? .title : .title2)
                        .fontWeight(large ? .medium : .regular)
                        .foregroundColor(labelColor)
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)

            }
            if let status {
                HStack {
                    Spacer()
                    Text("Status: \(status)")
                        .font(.title2)
                }.padding()
            }
        }
    }
}
// MARK: -
struct ThreeAmounts_Previews: PreviewProvider {
    static var previews: some View {
        let common = TransactionCommon(type: .withdrawal,
                                    txState: TransactionState(major: .done),
                            amountEffective: try! Amount(fromString: LONGCURRENCY + ":0.1"),
                                  amountRaw: try! Amount(fromString: LONGCURRENCY + ":0.2"),
                              transactionId: "someTxID",
                                  timestamp: Timestamp(from: 1_666_666_000_000),
                                  txActions: [])
        Group {
            List {
                ThreeAmounts(common: common, topTitle: "Withdrawal", baseURL: DEMOEXCHANGE, large: 1==1)
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
