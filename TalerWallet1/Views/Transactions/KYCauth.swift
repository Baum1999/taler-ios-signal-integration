/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

struct KYCauth: View {
    let stack: CallStack
    let common: TransactionCommon

    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var accountID = 0
    @State private var listID = UUID()

    func redraw(_ newAccount: Int) -> Void {
        if newAccount != accountID {
            accountID = newAccount
            withAnimation { listID = UUID() }
        }
    }

    func validDetails(_ paytoUris: [String]) -> [ExchangeAccountDetails] {
        var details: [ExchangeAccountDetails] = []
        for paytoUri in paytoUris {
            let payTo = PayTo(paytoUri)
            let amount = common.kycAuthTransferInfo?.amount
            let detail = ExchangeAccountDetails(status: "ok",
                                              paytoUri: paytoUri,
                                        transferAmount: amount,
                                                 scope: common.scopes[0])
            details.append(detail)
        }
        return details
    }

    var body: some View {
        if let info = common.kycAuthTransferInfo {
            let debitPayTo = PayTo(info.debitPaytoUri)
            let amount = info.amount
            let amountStr = amount.formatted(specs: nil,
                                        isNegative: false,
                                             scope: common.scopes[0])
            let amountValue = amount.valueStr
            let creditPaytoUris = info.creditPaytoUris
            let validDetails = validDetails(creditPaytoUris)
            if !validDetails.isEmpty {
                let countPaytos = creditPaytoUris.count
                let account = validDetails[accountID]

                Text("You need to prove having control over the bank account for the deposit.")
                    .bold()
                    .fixedSize(horizontal: false, vertical: true)       // wrap in scrollview
                    .multilineTextAlignment(.leading)                   // otherwise
                    .listRowSeparator(.hidden)

                if countPaytos > 1 {
                    if countPaytos > 3 { // too many for SegmentControl
                        AccountPicker(title: String(localized: "Bank"),
                                      value: $accountID,
                             accountDetails: validDetails,
                                     action: redraw)
                        .listRowSeparator(.hidden)
                        .pickerStyle(.menu)
                    } else {
                        SegmentControl(value: $accountID,
                              accountDetails: validDetails,
                                      action: redraw)
                        .listRowSeparator(.hidden)
                    }
                } else if let creditPaytoUri = creditPaytoUris.first {
                    if let bankName = account.bankLabel {
                        Text(bankName + ":   " + amountStr.0)
                            .accessibilityLabel(bankName + ":   " + amountStr.1)
//                    } else {
//                        Text(amountStr)
                    }
                }
                let payto = PayTo(account.paytoUri)
                if let receiverStr = payto.receiver {
                    let wireDetails = ManualDetailsWireV(stack: stack.push(),
                                                    reservePub: info.accountPub,
                                                         payto: payto,
                                                  restrictions: account.creditRestrictions,
                                                   amountValue: amountValue,
                                                     amountStr: amountStr,
                                                     obtainStr: nil,        // only for withdrawal
                                                     debitIBAN: debitPayTo.iban)
                    NavigationLink(destination: wireDetails) {
                        Text(minimalistic ? "Instructions"
                                          : "Wire transfer instructions")
                        .talerFont(.title3)
                    }
                }
            }
        }
    } // body
}
