/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
import taler_swift

// pretty much the same as ManualDetailsV
struct KYCauth: View {
    let stack: CallStack
    let common: TransactionCommon

    var body: some View {
        if let info = common.kycAuthTransferInfo {
            let debitPayTo = PayTo(info.debitPaytoUri)
            let accountDetails = info.transferOptionsExt
            if let validDetails = accountDetails.validDetails {
                WireTransferView(stack: stack.push(),
                                 title: String(localized: "You need to prove having control over the bank account for the deposit.", comment: ""),
                                 isKYC: true,
                            reservePub: info.accountPub,
                             amountRaw: info.amount,
                       amountEffective: nil,
                             debitIBAN: debitPayTo.iban,
                          validDetails: validDetails)
            } else { ErrorView(stack.push(), title: "KYC Error", message: "No valid details") }
        } else { ErrorView(stack.push(), title: "KYC Error", message: "No KYC infos") }
    } // body
}
