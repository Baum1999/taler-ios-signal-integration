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

struct KycData {
    let kycAmount: Amount
    let debitIBAN: String
}
// pretty much the same as ManualDetailsV
struct KYCauth: View {
    let stack: CallStack
    let common: TransactionCommon

    var body: some View {
        let kycErr = "KYC Error"
        if let info = common.kycAuthTransferInfo {
            let debitPayTo = PayTo(info.debitPaytoUri)
            if let debitIban = debitPayTo.iban {
                let kycData = KycData(kycAmount: info.amount, debitIBAN: debitIban)
                let accountDetails = info.transferOptionsExt
                if let validDetails = accountDetails.validDetails {
                    WireTransferView(stack: stack.push(),
                                     title: String(localized: "You need to prove having control over the bank account for the deposit.", comment: ""),
                                reservePub: info.accountPub,
                                 obtainStr: nil,
                                   kycData: kycData,
                              validDetails: validDetails)
                } else { ErrorView(stack.push(), title: kycErr, message: "No valid details") }
            } else { ErrorView(stack.push(), title: kycErr, message: "No IBAN") }
        } else { ErrorView(stack.push(), title: kycErr, message: "No KYC infos") }
    } // body
}
