/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct ManualDetails: View {
    var common : TransactionCommon
    var details : WithdrawalDetails
    var body: some View {
        if let paytoUris = details.exchangePaytoUris {
            let payto = paytoUris[0]
            let payURL = URL(string: payto)
            let iban = payURL?.iban ?? "unknown IBAN"
            let amount = common.amountRaw.readableDescription
            Text("Make a wire transfer of \(amount) to:")
                .listRowSeparator(.hidden)
            HStack {
                Text(iban)
                Spacer()
                CopyButton(textToCopy: iban, vertical: true)
                    .disabled(false)
            }   .padding(.leading)
                .padding(.vertical, -8)
                .listRowSeparator(.hidden)
            Text("and use the transaction subject:")
                .listRowSeparator(.hidden)
            HStack {
                Text(details.reservePub)
                Spacer()
                CopyButton(textToCopy: details.reservePub, vertical: true)
                    .disabled(false)
            }   .padding(.leading)
                .padding(.vertical, -8)
                .listRowSeparator(.hidden)
            HStack {
                Spacer()
                ShareButton(textToShare: payto, dismissFirst: false)
                    .disabled(false)
                Spacer()
            }   .listRowSeparator(.hidden)
            Text("Payto URL")
                .font(.footnote)
                .foregroundColor(Color.yellow)   // clear
                .padding(.vertical, -8)
                .listRowSeparator(.automatic)
        }
    }
}
// MARK: -
#if DEBUG
struct ManualDetails_Previews: PreviewProvider {
    static var previews: some View {
        let common = TransactionCommon(type: .withdrawal,
                                    txState: TransactionState(major: .done),
                            amountEffective: try! Amount(fromString: LONGCURRENCY + ":1.1"),
                                  amountRaw: try! Amount(fromString: LONGCURRENCY + ":2.2"),
                              transactionId: "someTxID",
                                  timestamp: Timestamp(from: 1_666_666_000_000),
                                  txActions: [])
        let details = WithdrawalDetails(type: .manual, reservePub: "ReSeRvEpUbLiC_KeY_FoR_WiThDrAwAl", reserveIsReady: false,
                                        exchangePaytoUris:["payto://iban/SANDBOXX/DE159593?receiver-name=Exchange+Company"])
        List {
            ManualDetails(common: common, details: details)
        }
    }
}
#endif
