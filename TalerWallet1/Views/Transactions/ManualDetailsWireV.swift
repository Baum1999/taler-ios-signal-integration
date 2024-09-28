/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import OrderedCollections
import taler_swift

struct TransferRestrictionsV: View {
    let amountStr: String
    let obtainStr: String
    let restrictions: [AccountRestriction]?

    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var selectedLanguage = Locale.preferredLanguageCode

    var body: some View {
        VStack(alignment: .leading) {
            let amountNBS = amountStr.nbs
            let obtainNBS = obtainStr.nbs
            Text(minimalistic ? "Transfer \(amountNBS) to the Payment Service."
                 : "You need to transfer \(amountNBS) from your regular bank account to the Payment Service Provider to receive \(obtainNBS) as electronic cash in this wallet.")
                .talerFont(.body)
                .multilineTextAlignment(.leading)
            if let restrictions {
                ForEach(restrictions) { restriction in
                    if let hintsI18 = restriction.human_hint_i18n {
                        //                        let sortedDict = OrderedDictionary(uniqueKeys: hintsI18.keys, values: hintsI18.values)
                        //                        var sorted: OrderedDictionary<String:String>
                        let sortedDict = OrderedDictionary(uncheckedUniqueKeysWithValues: hintsI18.sorted { $0.key < $1.key })
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
    let details : WithdrawalDetails
    let receiverStr: String
    let iban: String?
    let xTaler: String
    let amountStr: String
    let obtainStr: String
    let account: WithdrawalExchangeAccountDetails

    @AppStorage("minimalistic") var minimalistic: Bool = false
    let navTitle = String(localized: "Wire transfer", comment: "ViewTitle of wire-transfer instructions")

    var body: some View {
        List {
            let cryptocode = HStack {
                Text(details.reservePub)
                    .monospacedDigit()
                    .accessibilityLabel(Text("Cryptocode", comment: "VoiceOver"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                CopyButton(textToCopy: details.reservePub, vertical: true)
                    .accessibilityLabel(Text("Copy the cryptocode", comment: "VoiceOver"))
                    .disabled(false)
            }   .padding(.leading)
            let payeeCode = HStack {
                VStack(alignment: .leading) {
                    Text("Payee:")
                        .talerFont(.subheadline)
                    Text(receiverStr)
                        .monospacedDigit()
                        .padding(.leading)
                }   .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Payee", comment: "VoiceOver"))
                CopyButton(textToCopy: receiverStr, vertical: true)
                    .accessibilityLabel(Text("Copy the payee", comment: "VoiceOver"))
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
                    .accessibilityLabel(Text("IBAN of the payee", comment: "VoiceOver"))
                CopyButton(textToCopy: iban ?? EMPTYSTRING, vertical: true)
                    .accessibilityLabel(Text("Copy the IBAN", comment: "VoiceOver"))
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
                    .accessibilityLabel(Text("account of the payee", comment: "VoiceOver"))
                CopyButton(textToCopy: xTaler, vertical: true)
                    .accessibilityLabel(Text("Copy the account", comment: "VoiceOver"))
                    .disabled(false)
            }   .padding(.top, -8)
            let step1 = Text(minimalistic ? "**Step 1:** Copy+Paste this subject:"
                             : "**Step 1:** Copy this code and paste it into the subject/purpose field in your banking app or bank website:")
                .talerFont(.body)
                .multilineTextAlignment(.leading)
            let mandatory = Text("This is mandatory, otherwise your money will not arrive in this wallet.")
                .bold()
                .talerFont(.body)
                .multilineTextAlignment(.leading)
                .listRowSeparator(.hidden)
            let step2i = Text(minimalistic ? "**Step 2:** Copy+Paste payee and IBAN:"
                              : "**Step 2:** If you don't already have it in your banking favorites list, then copy and paste payee and IBAN into the payee/IBAN fields in your banking app or website (and save it as favorite for the next time):")
                .talerFont(.body)
                .multilineTextAlignment(.leading)
                .padding(.top)
            let step2x = Text(minimalistic ? "**Step 2:** Copy+Paste payee and account:"
                              : "**Step 2:** Copy and paste payee and account into the corresponding fields in your banking app or website:")
                .talerFont(.body)
                .multilineTextAlignment(.leading)
                .padding(.top)
            let amountNBS = amountStr.nbs
            let step3 = Text(minimalistic ? "**Step 3:** Transfer \(amountNBS)."
                             : "**Step 3:** Finish the wire transfer of \(amountNBS) in your banking app or website, then this withdrawal will proceed automatically. Depending on your bank the transfer can take from minutes to two working days, please be patient.")
                .talerFont(.body)
                .multilineTextAlignment(.leading)
                .padding(.top)

            Group {
                TransferRestrictionsV(amountStr: amountStr,
                                      obtainStr: obtainStr,
                                      restrictions: account.creditRestrictions)
                .listRowSeparator(.visible)
                step1.listRowSeparator(.hidden)
                if !minimalistic {
                    mandatory
                }
                cryptocode.listRowSeparator(.hidden)
                if iban != nil {
                    step2i.listRowSeparator(.hidden)
                    payeeCode.listRowSeparator(.hidden)
                    ibanCode.listRowSeparator(.hidden)
                } else {
                    step2x.listRowSeparator(.hidden)
                    payeeCode.listRowSeparator(.hidden)
                    xTalerCode.listRowSeparator(.hidden)
                }
                step3.listRowSeparator(.visible)
            }
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
//                                    txState: TransactionState(major: .done),
//                            amountEffective: Amount(currency: LONGCURRENCY, cent: 110),
//                                  amountRaw: Amount(currency: LONGCURRENCY, cent: 220),
//                              transactionId: "someTxID",
//                                  timestamp: Timestamp(from: 1_666_666_000_000),
//                                  txActions: [])
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
//                             account: <#T##WithdrawalExchangeAccountDetails#>)
//        }
//    }
//}
#endif
