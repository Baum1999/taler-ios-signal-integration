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
    let debitIBAN: String
    let depositStr: (String, String)
    let debitPayto: String
}
// pretty much the same as ManualDetailsV
struct KYCauth: View {
    let stack: CallStack
    let common: TransactionCommon

    func title(_ depositStr: String) -> String {
        String(localized: "You need to prove having control over the bank account for the deposit of \(depositStr).")
    }

    var body: some View {
        let kycErr = String(localized: "KYC Error")
        if let info = common.kycAuthTransferInfo {
            let debitPayTo = PayTo(info.debitPaytoUri)
            if let debitIban = debitPayTo.iban {
                let accountDetails = info.transferOptionsExt
                if let validDetails = accountDetails.validDetails {
                    if let scope: ScopeInfo = common.scopes.first {
                        let depositStr = common.amountRaw.formatted(scope, isNegative: false)
                        let kycData = KycData(debitIBAN: debitIban, depositStr: depositStr,
                                             debitPayto: info.debitPaytoUri)
                        WireTransferView(stack: stack.push(),
                                         title: title(depositStr.0),
                                     titleA11y: title(depositStr.1),
                                    reservePub: info.accountPub,
                                     obtainStr: nil,
                                       kycData: kycData,
                                  validDetails: validDetails)
                    } else { ErrorView(stack.push(), title: kycErr, message: String(localized: "No scope")) }
                } else { ErrorView(stack.push(), title: kycErr, message: "No valid details") }
            } else {
                // TODO: What if payto contains no IBAN, but URL?
                ErrorView(stack.push(), title: kycErr, message: String(localized: "No IBAN"))
            }
        } else { ErrorView(stack.push(), title: kycErr, message: String(localized: "No KYC infos")) }
    } // body
}
