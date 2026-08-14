/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import OrderedCollections
import taler_swift

struct ManualDetailsV: View {
    let stack: CallStack
    let common: TransactionCommon
    let details: WithdrawalDetails

    var body: some View {
        if let accountDetails = details.exchangeCreditAccountDetails,
           let validDetails = accountDetails.validDetails {
            if let scope: ScopeInfo = common.scopes.first {
                let obtainStr = common.amountEffective.formatted(scope , isNegative: false)
                WireTransferView(stack: stack.push(),
                                 title: String(localized: "The payment service is waiting for your wire-transfer.", comment: ""),
                            reservePub: details.reservePub,
                             obtainStr: obtainStr,              // only for withdrawal
                               kycData: nil,                    // only for deposit auth
                          validDetails: validDetails)
            } else { ErrorView(stack.push(), title: "Payment Error", message: "No scope") }
        } else { ErrorView(stack.push(), title: "Payment Error", message: "No valid details") }
    } // body
}
// MARK: -
// called by ManualDetailsV (amount to transfer is chosen by user),
// and by KYCauth (user chose the amount to deposit - but first they must transfer kycAmount to the Exchange to prove having control over the account)
struct WireTransferView: View {
    let stack: CallStack
    let title: String
    let reservePub: String
    let obtainStr: (String, String)?        // only for withdrawal
    let kycData: KycData?                   // only for deposit auth
    let validDetails: AccountDetailsArray

    @EnvironmentObject private var model: WalletModel
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var validIndex = 0
    @State private var listID = UUID()

    func redraw(_ newIndex: Int) -> Void {
        if newIndex != validIndex {
            validIndex = newIndex
            withAnimation { listID = UUID() }
        }
    }

    @ViewBuilder func qrCodesRow(_ transferOptions: [TransferOption]) -> some View {
        let qrCodesForPayto = QRcodesForPayto(stack: stack.push(),
                                    transferOptions: transferOptions)
        NavigationLink(destination: qrCodesForPayto) {
            Text(minimalistic ? "QR"
                              : "Wire transfer QR codes")
            .talerFont(.title3)
        }
    }

    var body: some View {
        let validCount = validDetails.count         // guaranteed to be > 0
        // validDetails can shrink (e.g. when a conversion rate lookup starts failing)
        // while validIndex still points to an account which is gone by now
        let account = validDetails[min(validIndex, validCount - 1)]
        let json = account.toJSON()
        // transferAmount is the amount the user must wire - for an account which needs
        // currency conversion that is in the external currency, and thus different from amountRaw
        if kycData != nil || account.transferAmount != nil {
            if let transferOptions = account.transferOptions,
               // an option of type "uri" has neither paytoUri nor qrCodes - use one which has
               let firstOption = transferOptions.first(where: { $0.paytoUri != nil }) ?? transferOptions.first {
                let specs = account.currencySpecification
                let plannedAmount = kycData?.kycAmount ?? account.transferAmount!
                let amountStr = plannedAmount.formatted(specs: specs, isNegative: false)
                let amountValue = plannedAmount.valueStr
//            let _ = print(amountStr, " | ", obtainStr)
                if !minimalistic {
                    Text(title)
                        .bold()
                        .multilineTextAlignment(.leading)
                        .listRowSeparator(.hidden)
                }
                if validCount > 1 {
                    if validCount > 3 { // too many for SegmentControl
                        AccountPicker(title: String(localized: "Bank"),
                                      value: $validIndex,
                             accountDetails: validDetails,
                                     action: redraw)
                        .listRowSeparator(.hidden)
                        .pickerStyle(.menu)
                    } else {
                        SegmentControl(value: $validIndex, accountDetails: validDetails, action: redraw)
                            .listRowSeparator(.hidden)
                    }
                } else if let bankName = account.bankLabel {
                    Text(bankName + ":   " + amountStr.0)
                        .accessibilityLabel(bankName + ":   " + amountStr.1)
                } else {
                    Text(amountStr.0)
                        .accessibilityLabel(amountStr.1)
                }

                let countA = transferOptions.count
                let countB = firstOption.qrCodes?.count ?? 0

                if let paytoUri = firstOption.paytoUri {
                    let payto = PayTo(paytoUri)
                    if let receiverStr = payto.receiver {
                        let wireDetails = ManualDetailsWireV(stack: stack.push(),
                                                        reservePub: reservePub,
                                                             payto: payto,
                                                      restrictions: account.creditRestrictions,
                                                       amountValue: amountValue,
                                                         amountStr: amountStr,
                                                         obtainStr: obtainStr,              // only for withdrawal
                                                         debitIBAN: kycData?.debitIBAN      // only for deposit auth
                                            )
                        NavigationLink(destination: wireDetails) {
                            Text(minimalistic ? "Instructions"
                                              : "Wire transfer instructions")
                            .talerFont(.title3)
                        }

                        Group {
                            if countA > 1 || countB > 1 {
                                qrCodesRow(transferOptions)
                            } else if countB > 0 {   // show the single QR directly
                                Text("If your banking software runs on another device, you can scan this QR code:")
                                    .listRowSeparator(.hidden)
                                QRcodeCopyShare(option: firstOption)
                                    .listRowSeparator(.automatic)
                            }
                        }.id(listID)
                            .talerFont(.body)
#if DEBUG
                        if developerMode {
                            if let iban = payto.iban {
                                Text(minimalistic ? "**Alternative:** Use this PayTo-Link:"
                                                  : "**Alternative:** If your bank already supports PayTo, you can use this PayTo-Link instead:")
                                    .multilineTextAlignment(.leading)
                                    .padding(.top)
                                    .listRowSeparator(.hidden)
                                let title = String(localized: "Share the PayTo URL", comment: "a11y")
                                let minTitle = String(localized: "Share PayTo", comment: "mini")
                                // TODO: chQRr
                                let textToShare = String("\(payto)\n\nIBAN: \(iban)\nReceiver: \(receiverStr)\nAmount: \(amountStr.1)\nSubject: \(reservePub)")
            let _ = print(textToShare)
                                ShareButton(textToShare, title: minimalistic ? minTitle : title)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .accessibilityLabel(Text(title))
                                    .disabled(false)
                                    .listRowSeparator(.hidden)
                            }
                        }
#endif
                    } else { ErrorView(stack.push(), title: "No receiver", message: json, copyable: true) }
                } else { ErrorView(stack.push(), title: "No payto URL", message: json, copyable: true) }
            } else { ErrorView(stack.push(), title: "No transfer options", message: json, copyable: true) }
        } else { ErrorView(stack.push(), title:  "No amount", message: json, copyable: true) }
    }
}
// MARK: -
#if DEBUG
struct ManualDetails_Previews: PreviewProvider {
    static var previews: some View {
        let common = TransactionCommon(type: .withdrawal,
                              transactionId: "someTxID",
                                  timestamp: Timestamp(from: 1_666_666_000_000),
                                     scopes: [],
                                    txState: TransactionState(major: .done),
                                  txActions: [],
                                  amountRaw: Amount(currency: LONGCURRENCY, cent: 220),
                            amountEffective: Amount(currency: LONGCURRENCY, cent: 110))
//        let payto = "payto://iban/SANDBOXX/DE159593?receiver-name=Exchange+Company"
        let details = WithdrawalDetails(type: .manual, 
                                  reservePub: "ReSeRvEpUbLiC_KeY_FoR_WiThDrAwAl",
                              reserveIsReady: false,
                                   confirmed: false)
        List {
            ManualDetailsV(stack: CallStack("Preview"), common: common, details: details)
        }
    }
}
#endif
