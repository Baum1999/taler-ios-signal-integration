/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift

struct AccountPicker: View {
    let title: String
    let value: Int
    let accountDetails: [WithdrawalExchangeAccountDetails]
    let action: (Int) -> Void

    @State private var selectedAccount = 0

    var body: some View {
        Picker(title, selection: $selectedAccount, content: {
            ForEach(0..<accountDetails.count, id: \.self, content: { index in
                let detail = accountDetails[index]
                let bankName = detail.bankName ?? "BankName " + String(index)
                let amountStr = detail.transferAmount.readableDescription
                Text(bankName + ":   " + amountStr)
                    .tag(index)
            })
        })
        .accessibilityFont(.title3)
        .pickerStyle(.menu)
        .onAppear() {
            withAnimation { selectedAccount = value }
        }
        .onChange(of: selectedAccount) { selected in
            action(selected)
        }
    }
}


struct ManualDetailsV: View {
    var common : TransactionCommon
    var details : WithdrawalDetails

    @AppStorage("iconOnly") var iconOnly: Bool = false
    @State private var accountID = 0
    @State private var listID = UUID()

    func redraw(_ newAccount: Int) -> Void {
        if newAccount != accountID {
            accountID = newAccount
            withAnimation { listID = UUID() }
        }
    }

    var body: some View {
        if let accountDetails = details.exchangeCreditAccountDetails {
            AccountPicker(title: String(localized: "Bank"), value: accountID,
                          accountDetails: accountDetails, action: redraw)
            let account = accountDetails[accountID]
            let payto = account.paytoUri
            let payURL = URL(string: payto)
            let iban = payURL?.iban ?? "unknown IBAN"
            let amountStr = account.transferAmount.readableDescription        // TODO: formatter
            let obtainStr = common.amountRaw.readableDescription
            Group {
                Text(iconOnly ? "Transfer \(amountStr) to the Exchange."
                              : "You need to transfer \(amountStr) from your regular bank account to the Exchange to receive \(obtainStr) as electronic cash in this wallet.")
                Text(iconOnly ? "**Step 1:** Copy+Paste this subject:"
                              : "**Step 1:** Copy this code and paste it into the subject/purpose field in your banking app or bank website:")
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
                Text(iconOnly ? "**Step 2:** Copy+Paste this IBAN:"
                              : "**Step 2:** If you don't already have it in your banking favourites list, then copy and paste this IBAN into the receiver IBAN field in your banking app or website (and save it as favourite for the next time):")
                    .multilineTextAlignment(.leading)
                    .padding(.top)
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
                Text(iconOnly ? "**Step 3:** Transfer \(amountStr)."
                              : "**Step 3:** Finish the wire transfer of \(amountStr) in your banking app or website, then this withdrawal will proceed automatically.")
                    .multilineTextAlignment(.leading)
                    .padding(.top)
                    .listRowSeparator(.visible)
                Text(iconOnly ? "**Alternative:** Use this PayTo-Link:"
                              : "**Alternative:** If your bank already supports PayTo, you can use this PayTo-Link instead:")
                    .multilineTextAlignment(.leading)
                    .padding(.top)
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
            }.id(listID)
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
        let payto = "payto://iban/SANDBOXX/DE159593?receiver-name=Exchange+Company"
        let details = WithdrawalDetails(type: .manual, 
                                  reservePub: "ReSeRvEpUbLiC_KeY_FoR_WiThDrAwAl",
                              reserveIsReady: false,
                                   confirmed: false)
        List {
            ManualDetailsV(common: common, details: details)
        }
    }
}
#endif
