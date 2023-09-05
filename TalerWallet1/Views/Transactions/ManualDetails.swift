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
            Group {
                Text("You need to transfer \(amount) from your regular bank account to the Exchange.")
                Text("Step 1: Copy this code and paste it into the subject/purpose field in your banking app or bank website.\nThis is mandatory, otherwise your money will not arrive in this wallet.")
                    .multilineTextAlignment(.leading)
                    .listRowSeparator(.hidden)
                HStack {
                    Text(details.reservePub)
                        .monospacedDigit()
                        .accessibilityLabel("Cryptocode")
                    Spacer()
                    CopyButton(textToCopy: details.reservePub, vertical: true)
                        .accessibilityLabel("Copy the cryptocode")
                        .disabled(false)
                }   .padding(.leading)
                    .listRowSeparator(.hidden)
                Text("Step 2: If you don't already have it in your banking favourites list, then copy and paste this IBAN into the receiver IBAN field in your banking app or website:")
                    .multilineTextAlignment(.leading)
                    .listRowSeparator(.hidden)
                HStack {
                    Text(iban)
                        .monospacedDigit()
                    Spacer()
                    CopyButton(textToCopy: iban, vertical: true)
                        .accessibilityLabel("Copy the IBAN")
                        .disabled(false)
                }   .padding(.leading)
                    .padding(.top, -8)
                    .listRowSeparator(.hidden)
                Text("Step 3: Finish the wire transfer of \(amount) in your banking app or website, then this withdrawal will proceed automatically.")
                    .multilineTextAlignment(.leading)
                    .listRowSeparator(.visible)
                Text("Alternative: If your bank already supports PayTo, you can use this PayTo-Link instead:")
                    .multilineTextAlignment(.leading)
                    .padding(.top, 2)
                    .listRowSeparator(.hidden)
                HStack {
                    Text(verbatim: "|")       // only reason for this leading-aligned text is to get a nice full length listRowSeparator
                        .accessibilityHidden(true)
                        .foregroundColor(Color.clear)
                    Spacer()
                    ShareButton(textToShare: payto)
                        .accessibilityLabel("Share the PayTo URL")
                        .disabled(false)
                    Spacer()
                }   .listRowSeparator(.automatic)
            }.font(.talerBody)
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
