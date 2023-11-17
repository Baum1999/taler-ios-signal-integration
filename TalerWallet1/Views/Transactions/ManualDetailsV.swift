/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct ManualDetailsV: View {
    var common : TransactionCommon
    var details : WithdrawalDetails

    @AppStorage("iconOnly") var iconOnly: Bool = false

    var body: some View {
        if let paytoUris = details.exchangePaytoUris {
            let payto = paytoUris[0]
            let payURL = URL(string: payto)
            let iban = payURL?.iban ?? "unknown IBAN"
            let amountStr = common.amountRaw.readableDescription        // TODO: formatter
            Group {
                Text(iconOnly ? "Transfer \(amountStr) to the Exchange."
                              : "You need to transfer \(amountStr) from your regular bank account to the Exchange.")
                Text(iconOnly ? "Step 1: Copy+Paste this subject:"
                              : "Step 1: Copy this code and paste it into the subject/purpose field in your banking app or bank website:")
                        .multilineTextAlignment(.leading)
                        .listRowSeparator(.hidden)
                if !iconOnly {
                    Text("This is mandatory, otherwise your money will not arrive in this wallet.")
                        .bold()
                        .multilineTextAlignment(.leading)
                        .listRowSeparator(.hidden)
                }
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
                Text(iconOnly ? "Step 2: Copy+Paste this IBAN:"
                              : "Step 2: If you don't already have it in your banking favourites list, then copy and paste this IBAN into the receiver IBAN field in your banking app or website:")
                    .multilineTextAlignment(.leading)
                    .listRowSeparator(.hidden)
                HStack {
                    Text(iban)
                        .monospacedDigit()
                        .accessibilityLabel("IBAN of the exchange")
                    Spacer()
                    CopyButton(textToCopy: iban, vertical: true)
                        .accessibilityLabel("Copy the IBAN")
                        .disabled(false)
                }   .padding(.leading)
                    .padding(.top, -8)
                    .listRowSeparator(.hidden)
                Text(iconOnly ? "Step 3: Transfer \(amountStr)."
                              : "Step 3: Finish the wire transfer of \(amountStr) in your banking app or website, then this withdrawal will proceed automatically.")
                    .multilineTextAlignment(.leading)
                    .listRowSeparator(.visible)
                Text(iconOnly ? "Or use this PayTo-Link:"
                              : "Alternative: If your bank already supports PayTo, you can use this PayTo-Link instead:")
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
            }
                .accessibilityFont(.body)
        }
    }
}
// MARK: -
#if DEBUG
struct ManualDetails_Previews: PreviewProvider {
    static var previews: some View {
        let common = TransactionCommon(type: .withdrawal,
                                    txState: TransactionState(major: .done),
                            amountEffective: Amount(currency: LONGCURRENCY, cent: 110),
                                  amountRaw: Amount(currency: LONGCURRENCY, cent: 220),
                              transactionId: "someTxID",
                                  timestamp: Timestamp(from: 1_666_666_000_000),
                                  txActions: [])
        let details = WithdrawalDetails(type: .manual, reservePub: "ReSeRvEpUbLiC_KeY_FoR_WiThDrAwAl", reserveIsReady: false,
                                        exchangePaytoUris:["payto://iban/SANDBOXX/DE159593?receiver-name=Exchange+Company"])
        List {
            ManualDetailsV(common: common, details: details)
        }
    }
}
#endif
