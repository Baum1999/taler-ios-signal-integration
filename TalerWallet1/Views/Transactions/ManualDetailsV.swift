/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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

    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var accountID = 0
    @State private var listID = UUID()
    @State private var qrCodeSpecs: [QrCodeSpec] = []

    func redraw(_ newAccount: Int) -> Void {
        if newAccount != accountID {
            accountID = newAccount
            withAnimation { listID = UUID() }
        }
    }
    func validDetails(_ details: [ExchangeAccountDetails]) -> [ExchangeAccountDetails] {
        details.filter { detail in
            detail.status.lowercased() == "ok"
        }
    }

    @MainActor
    private func viewDidLoad(_ paytoUri: String) async {
        if let specs = try? await model.getQrCodesForPayto(paytoUri) {
            qrCodeSpecs = specs
            return
        }
        qrCodeSpecs = []
    }

    var body: some View {
        if let accountDetails = details.exchangeCreditAccountDetails {
            let validDetails = validDetails(accountDetails)
            if validDetails.count > 0 {
                let account = validDetails[accountID]
                if let amount = account.transferAmount {
                    let specs = account.currencySpecification
                    let amountStr = common.amountRaw.formatted(specs: specs, isNegative: false)
                    let amountValue = common.amountRaw.valueStr
                    let obtainStr = common.amountEffective.formatted(specs: specs, isNegative: false)
//            let _ = print(amountStr, " | ", obtainStr)
                    if !minimalistic {
                        Text("The payment service is waiting for your wire-transfer.")
                            .bold()
                            .multilineTextAlignment(.leading)
                            .listRowSeparator(.hidden)
                    }
                    if validDetails.count > 1 {
                        if validDetails.count > 3 { // too many for SegmentControl
                            AccountPicker(title: String(localized: "Bank"),
                                          value: $accountID,
                                 accountDetails: validDetails,
                                         action: redraw)
                            .listRowSeparator(.hidden)
                            .pickerStyle(.menu)
                        } else {
                            SegmentControl(value: $accountID, accountDetails: validDetails, action: redraw)
                                .listRowSeparator(.hidden)
                        }
                    } else if let amount = account.transferAmount {
                        if let bankName = account.bankLabel {
                            Text(bankName + ":   " + amountStr.0)
                                .accessibilityLabel(bankName + ":   " + amountStr.1)
//                        } else {
//                            Text(amountStr)
                        }
                    }
                    let payto = PayTo(account.paytoUri)
                    if let receiverStr = payto.receiver {
                        let wireDetails = ManualDetailsWireV(stack: stack.push(),
                                                        reservePub: details.reservePub,
                                                       receiverStr: receiverStr,
                                                       receiverZip: payto.postalCode,
                                                      receiverTown: payto.town,
                                                              iban: payto.iban,
                                                            cyclos: payto.cyclos ?? EMPTYSTRING,
                                                            xTaler: payto.xTaler ?? EMPTYSTRING,
                                                       amountValue: amountValue,
                                                         amountStr: amountStr,
                                                         obtainStr: obtainStr,
                                                         debitIBAN: nil,        // only for deposit auth
                                                           account: account)
                        Group {
                            NavigationLink(destination: wireDetails) {
                                Text(minimalistic ? "Instructions"
                                                  : "Wire transfer instructions")
                                .talerFont(.title3)
                            }

                            if qrCodeSpecs.count > 0 {
                                let qrCodesForPayto = QRcodesForPayto(stack: stack.push(), qrCodeSpecs: $qrCodeSpecs)
                                NavigationLink(destination: qrCodesForPayto) {
                                    Text(minimalistic ? "QR"
                                                      : "Wire transfer QR codes")
                                    .talerFont(.title3)
                                }
                                .listRowSeparator(.automatic)
                            }
#if DEBUG
                            if let iban = payto.iban {
                                Text(minimalistic ? "**Alternative:** Use this PayTo-Link:"
                                    : "**Alternative:** If your bank already supports PayTo, you can use this PayTo-Link instead:")
                                    .multilineTextAlignment(.leading)
                                    .padding(.top)
                                    .listRowSeparator(.hidden)
                                let title = String(localized: "Share the PayTo URL", comment: "a11y")
                                let minTitle = String(localized: "Share PayTo", comment: "mini")
                                let textToShare = String("\(payto)\n\nIBAN: \(iban)\nReceiver: \(receiverStr)\nAmount: \(amountStr.1)\nSubject: \(details.reservePub)")
            let _ = print(textToShare)
                                ShareButton(textToShare: textToShare, title: minimalistic ? minTitle : title)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .accessibilityLabel(Text(title))
                                    .disabled(false)
                                    .listRowSeparator(.hidden)
                            }
#endif
                        }.id(listID)
                            .talerFont(.body)
                            .task { await viewDidLoad(account.paytoUri) }
                    } else {
                        // TODO: Error No payto URL
                    }
                } else {
                    // TODO: Error No amount
                }
            } else {
                // TODO: Error none of the details is valid
            }
        } else {
            // TODO: Error No exchangeCreditAccountDetails
        }
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
        let payto = "payto://iban/SANDBOXX/DE159593?receiver-name=Exchange+Company"
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
