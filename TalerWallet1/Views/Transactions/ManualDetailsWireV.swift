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

struct TransferRestrictionsV: View {
    let amountStr: (String, String)
    let obtainStr: (String, String)?
    let debitIBAN: String?
    let restrictions: [AccountRestriction]?

    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var selectedLanguage = Locale.preferredLanguageCode

    private func transferMini(_ amountS: String) -> String {
        let amountNBS = amountS.nbs
        return String(localized: "Transfer \(amountNBS) to the payment service.")
    }
    private func transferMaxi(_ amountS: String, _ obtainS: String) -> String {
        let amountNBS = amountS.nbs
        let obtainNBS = obtainS.nbs
        return String(localized: "You need to transfer \(amountNBS) from your regular bank account to the payment service to receive \(obtainNBS) as digital cash in this wallet.")
    }

    private func authMini(_ amountS: String, _ debitS: String) -> String {
        let amountNBS = amountS.nbs
        return String(localized: "Transfer \(amountNBS) from account \(debitS) to verify having control over it.")
    }
    private func authMaxi(_ amountS: String, _ debitS: String) -> String {
        let amountNBS = amountS.nbs
        return String(localized: "You need to transfer \(amountNBS) to the payment service from your bank account \(debitS) to verify having control over it. Don't use a different bank account, or the verification will fail.")
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let obtainStr {
                Text(minimalistic ? transferMini(amountStr.0)
                                  : transferMaxi(amountStr.0, obtainStr.0))
                    .accessibilityLabel(minimalistic ? transferMini(amountStr.1)
                                                     : transferMaxi(amountStr.1, obtainStr.1))
                    .talerFont(.body)
                    .multilineTextAlignment(.leading)
            } else if let debitIBAN {
                Text(minimalistic ? authMini(amountStr.0, debitIBAN)
                                  : authMaxi(amountStr.0, debitIBAN))
                    .accessibilityLabel(minimalistic ? authMini(amountStr.1, debitIBAN)
                                                     : authMaxi(amountStr.1, debitIBAN))
                    .talerFont(.body)
                    .multilineTextAlignment(.leading)
            }
            if let restrictions {
                ForEach(restrictions) { restriction in
                    if let hintsI18n = restriction.human_hint_i18n {
//                        let sortedDict = OrderedDictionary(uniqueKeys: hintsI18n.keys, values: hintsI18n.values)
//                        var sorted: OrderedDictionary<String:String>
                        let sortedDict = OrderedDictionary(uncheckedUniqueKeysWithValues: hintsI18n.sorted { $0.key < $1.key })
                        Picker("Restriction:", selection: $selectedLanguage) {
                            ForEach(sortedDict.keys, id: \.self) {
                                Text(sortedDict[$0] ?? "missing hint")
                            }
                        }
                    } else if let hint = restriction.human_hint {
                        Text(hint)
                    }
                }
            }
        }
    }
}
// MARK: -
struct ManualDetailsWireV: View {
    let stack: CallStack
    let reservePub: String
    let receiverStr: String
//    let receiverAux: String?
    let receiverZip: String?
    let receiverTown: String?
    let iban: String?
    let xTaler: String
    let amountValue: String             // string representation of the value, formatted as "`integer`.`fraction`"
    let amountStr: (String, String)
    let obtainStr: (String, String)?    // only for withdrawal
    let debitIBAN: String?              // only for deposit auth
    let account: ExchangeAccountDetails

    @AppStorage("minimalistic") var minimalistic: Bool = false
    let navTitle = String(localized: "Wire transfer", comment: "ViewTitle of wire-transfer instructions")

    private func step3(_ amountS: String) -> String {
        let amountNBS = amountS.nbs
        let bePatient = String(localized: "Depending on your bank the transfer can take from minutes to two working days, please be patient.")
        if let debitIBAN {
            return minimalistic ? String(localized: "Transfer \(amountNBS) from \(debitIBAN).")
                                : String(localized: "Finish the wire transfer of \(amountNBS) in your banking app or website to verify your bank account \(debitIBAN).") + "\n" + bePatient
        }
        return minimalistic ? String(localized: "Transfer \(amountNBS).")
                            : String(localized: "Finish the wire transfer of \(amountNBS) in your banking app or website, then this withdrawal will proceed automatically.") + "\n" + bePatient
    }

//    func buildReceiver() -> String {
//        if let receiverAux {
//            return receiverStr + ", " + receiverAux
//        }
//        return receiverStr
//    }

    @ViewBuilder func payeeZip() -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Zip code:")
                    .talerFont(.subheadline)
                Text(receiverZip ?? EMPTYSTRING)
                    .monospacedDigit()
                    .padding(.leading)
            }   .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Zip code", comment: "a11y"))
            CopyButton(textToCopy: receiverZip ?? EMPTYSTRING, vertical: true)
                .accessibilityLabel(Text("Copy the zip code", comment: "a11y"))
                .disabled(false)
        }   .padding(.top, -8)
    }

    @ViewBuilder func payeeTown() -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("City:")
                    .talerFont(.subheadline)
                Text(receiverTown ?? EMPTYSTRING)
                    .monospacedDigit()
                    .padding(.leading)
            }   .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("City", comment: "a11y"))
            CopyButton(textToCopy: receiverTown ?? EMPTYSTRING, vertical: true)
                .accessibilityLabel(Text("Copy the city", comment: "a11y"))
                .disabled(false)
        }   .padding(.top, -8)
    }

    var body: some View {
        List {
            let cryptocode = HStack {
                Text(reservePub)
                    .monospacedDigit()
                    .accessibilityLabel(Text("Cryptocode", comment: "a11y"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                CopyButton(textToCopy: reservePub, vertical: true)
                    .accessibilityLabel(Text("Copy the cryptocode", comment: "a11y"))
                    .disabled(false)
            }   .padding(.leading)
            let payeeCode = HStack {
                VStack(alignment: .leading) {
                    Text("Recipient:")
                        .talerFont(.subheadline)
                    Text(receiverStr)
                        .monospacedDigit()
                        .padding(.leading)
//                    if let receiverAux {
//                        Text(receiverAux)
//                            .monospacedDigit()
//                            .padding(.leading)
//                    }
                }   .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Recipient", comment: "a11y"))
                CopyButton(textToCopy: receiverStr, vertical: true)
//                CopyButton(textToCopy: buildReceiver(), vertical: true)
                    .accessibilityLabel(Text("Copy the recipient", comment: "a11y"))
                    .disabled(false)
            }   .padding(.top, -8)
            let ibanCode = HStack {
                VStack(alignment: .leading) {
                    Text("IBAN:")
                        .talerFont(.subheadline)
                    Text(iban ?? EMPTYSTRING)
                        .monospacedDigit()
                        .padding(.leading)
                }   .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("IBAN of the recipient", comment: "a11y"))
                CopyButton(textToCopy: iban ?? EMPTYSTRING, vertical: true)
                    .accessibilityLabel(Text("Copy the IBAN", comment: "a11y"))
                    .disabled(false)
            } //  .padding(.top, -8)
            let amountCode = HStack {
                VStack(alignment: .leading) {
                    Text("Amount:")
                        .talerFont(.subheadline)
                    Text(amountStr.0)
                        .accessibilityLabel(amountStr.1)
                        .monospacedDigit()
                        .padding(.leading)
                }   .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Amount to transfer", comment: "a11y"))
                CopyButton(textToCopy: amountValue, vertical: true)             // only digits + separator, no currency name or symbol
                    .accessibilityLabel(Text("Copy the amount", comment: "a11y"))
                    .disabled(false)
            }   .padding(.top, -8)
            let xTalerCode = HStack {
                VStack(alignment: .leading) {
                    Text("Account:")
                        .talerFont(.subheadline)
                    Text(xTaler)
                        .monospacedDigit()
                        .padding(.leading)
                }   .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("account of the recipient", comment: "a11y"))
                CopyButton(textToCopy: xTaler, vertical: true)
                    .accessibilityLabel(Text("Copy the account", comment: "a11y"))
                    .disabled(false)
            }   .padding(.top, -8)
            let step1 = Text(minimalistic ? "**Step 1:** Copy+Paste this subject:"
                             : "**Step 1:** Copy this code and paste it into the subject/purpose field in your banking app or bank website:")
                .talerFont(.body)
                .multilineTextAlignment(.leading)
            let manda1 = String(localized: "This is mandatory, otherwise your money will not arrive in this wallet.")
            let manda2 = String(localized: "This is mandatory, otherwise the verification will fail.")
            let mandatory = Text(debitIBAN == nil ? manda1 : manda2)
                .bold()
                .talerFont(.body)
                .multilineTextAlignment(.leading)
                .listRowSeparator(.hidden)
            let step2i = Text(minimalistic ? "**Step 2:** Copy+Paste recipient and IBAN:"
                              : "**Step 2:** If you don't already have it in your banking favorites list, then copy and paste recipient and IBAN into the recipient/IBAN fields in your banking app or website (and save it as favorite for the next time):")
                .talerFont(.body)
                .multilineTextAlignment(.leading)
                .padding(.top)
            let step2x = Text(minimalistic ? "**Step 2:** Copy+Paste recipient and account:"
                              : "**Step 2:** Copy and paste recipient and account into the corresponding fields in your banking app or website:")
                .talerFont(.body)
                .multilineTextAlignment(.leading)
                .padding(.top)
            let step3A11y = String(localized: "Step 3: \(step3(amountStr.1))", comment: "a11y")
            let step3Head: LocalizedStringKey = "**Step 3:** \(step3(amountStr.0))"
            let step3 = Text(step3Head)
                .accessibilityLabel(step3A11y)
                .talerFont(.body)
                .multilineTextAlignment(.leading)

            Group {
                TransferRestrictionsV(amountStr: amountStr,
                                      obtainStr: obtainStr,
                                      debitIBAN: debitIBAN,
                                   restrictions: account.creditRestrictions)
                .listRowSeparator(.visible)
                step1
                if !minimalistic {
                    mandatory
                }
                cryptocode
                if iban != nil {
                    step2i
                    payeeCode
                    if let receiverZip {
                        payeeZip()
                    }
                    if let receiverTown {
                        payeeTown()
                    }
                    ibanCode
                } else {
                    step2x
                    payeeCode
                    xTalerCode
                }
                amountCode
//                    .padding(.top)
                step3 // .padding(.top, 6)
            }.listRowSeparator(.hidden)
        }
        .navigationTitle(navTitle)
        .onAppear() {
//            symLog.log("onAppear")
            DebugViewC.shared.setViewID(VIEW_WITHDRAW_INSTRUCTIONS, stack: stack.push())
        }
    }
}

// MARK: -
#if DEBUG
//struct ManualDetailsWire_Previews: PreviewProvider {
//    static var previews: some View {
//        let common = TransactionCommon(type: .withdrawal,
//                              transactionId: "someTxID",
//                                  timestamp: Timestamp(from: 1_666_666_000_000),
//                                    txState: TransactionState(major: .done),
//                                  txActions: [])
//                            amountEffective: Amount(currency: LONGCURRENCY, cent: 110),
//                                  amountRaw: Amount(currency: LONGCURRENCY, cent: 220),
//        let payto = "payto://iban/SANDBOXX/DE159593?receiver-name=Exchange+Company"
//        let details = WithdrawalDetails(type: .manual,
//                                  reservePub: "ReSeRvEpUbLiC_KeY_FoR_WiThDrAwAl",
//                              reserveIsReady: false,
//                                   confirmed: false)
//        List {
//            ManualDetailsWireV(stack: CallStack("Preview"),
//                             details: details,
//                         receiverStr: <#T##String#>,
//                                iban: <#T##String?#>,
//                              xTaler: <#T##String#>,
//                           amountStr: <#T##String#>,
//                           obtainStr: <#T##String#>,
//                             account: T##ExchangeAccountDetails)
//        }
//    }
//}
#endif
