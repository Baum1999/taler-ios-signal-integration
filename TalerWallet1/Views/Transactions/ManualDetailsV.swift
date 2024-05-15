/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import OrderedCollections
import taler_swift

struct SegmentControl: View {
    let value: Int
    let accountDetails: [WithdrawalExchangeAccountDetails]
    let action: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var selectedAccount = 0
    @ScaledMetric var frameHeight = 80       // relative to fontSize

    public var body: some View {
        let count = accountDetails.count
        ZStack(alignment: .center) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 6.0)
                    .foregroundColor(WalletColors().pickerSelected(colorScheme, colorSchemeContrast))
                    .cornerRadius(6.0)
                    .padding(4)
                    .frame(width: geo.size.width / CGFloat(count))
                    .offset(x: geo.size.width / CGFloat(count) * CGFloat(selectedAccount), y: 0)
            }
            .frame(height: frameHeight)

            HStack(spacing: 0) {
                ForEach((0..<count), id: \.self) { index in
                    let detail = accountDetails[index]
                    let amount = detail.transferAmount
                    let bankName = detail.bankLabel
                    let amountStr = amount?.readableDescription ?? ""
                    let a11yLabel = bankName != nil ? (bankName! + " " + amountStr) : amountStr
                    VStack(spacing: 6) {
                        Text(amountStr)
                            .talerFont(.title3)
                        if let bankName {
                            Text(bankName)
                                .talerFont(.subheadline)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(a11yLabel)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(index == selectedAccount ? .isSelected : [])
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.150)) {
                            selectedAccount = index
                        }
                    }
                }
            }
        }
        .onAppear() {
            withAnimation { selectedAccount = value }
        }
        .onChange(of: selectedAccount) { selected in
            action(selected)
        }
        .background(
            RoundedRectangle(cornerRadius: 6.0)
                .fill(WalletColors().sideBackground)
        )
    }
}
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
                    if let amount = detail.transferAmount {
                        let amountStr = amount.readableDescription
                        if let bankName = detail.bankLabel {
                            Text(bankName + ":   " + amountStr)
                                .tag(index)
                        } else {
                            Text(amountStr)
                                .tag(index)
                        }
                    }
            })
        })
        .talerFont(.title3)
        .pickerStyle(.menu)
        .onAppear() {
            withAnimation { selectedAccount = value }
        }
        .onChange(of: selectedAccount) { selected in
            action(selected)
        }
    }
}
// MARK: -
struct TransferRestrictionsV: View {
    let amountStr: String
    let obtainStr: String
    let restrictions: [AccountRestriction]?

    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var selectedLanguage = Locale.preferredLanguageCode

    var body: some View {
        VStack(alignment: .leading) {
            Text(minimalistic ? "Transfer \(amountStr) to the Payment Service."
                              : "You need to transfer \(amountStr) from your regular bank account to the Payment Service Provider to receive \(obtainStr) as electronic cash in this wallet.")
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
struct ManualDetailsV: View {
    var common : TransactionCommon
    var details : WithdrawalDetails

    @AppStorage("minimalistic") var minimalistic: Bool = false
    @State private var accountID = 0
    @State private var listID = UUID()

    func redraw(_ newAccount: Int) -> Void {
        if newAccount != accountID {
            accountID = newAccount
            withAnimation { listID = UUID() }
        }
    }
    func validDetails(_ details: [WithdrawalExchangeAccountDetails]) -> [WithdrawalExchangeAccountDetails] {
        details.filter { detail in
            detail.status.lowercased() == "ok"
        }
    }

    func amountString(_ amount: Amount, specs: CurrencySpecification?, scope: ScopeInfo? = nil) -> String {
        if let specs {
            let myScope = scope ?? ScopeInfo(type: .madeUp, currency: amount.currencyStr)
            let currencyInfo = CurrencyInfo(scope: myScope, specs: specs,
                                        formatter: CurrencyFormatter.formatter(scope: myScope,
                                                                               specs: specs))
            return amount.string(currencyInfo)
        }
        return amount.string()
    }

    var body: some View {
        if let accountDetails = details.exchangeCreditAccountDetails {
            let validDetails = validDetails(accountDetails)
            if validDetails.count > 0 {
                let account = validDetails[accountID]
                if let amount = account.transferAmount {
                    let specs = account.currencySpecification
                    let amountStr = amountString(amount, specs: specs)
                    let obtainStr = common.amountRaw.string()
                    if !minimalistic {
                        Text("The Payment Service Provider is waiting for your wire-transfer.")
                            .bold()
                            .multilineTextAlignment(.leading)
                            .listRowSeparator(.hidden)
                    }
                    if validDetails.count > 1 {
                        if validDetails.count > 3 {
                            AccountPicker(title: String(localized: "Bank"), value: accountID,
                                          accountDetails: validDetails, action: redraw)
                            .listRowSeparator(.hidden)
                        } else {
                            SegmentControl(value: accountID, accountDetails: validDetails, action: redraw)
                                .listRowSeparator(.hidden)
                        }
                    } else if let amount = account.transferAmount {
                        if let bankName = account.bankLabel {
                            Text(bankName + ":   " + amountStr)
                        } else {
                            Text(amountStr)
                        }
                    }
                    let payto = account.paytoUri
                    let payURL = URL(string: payto)
                    if let queryParameters = payURL?.queryParameters {
                        let receiverStr = (queryParameters["receiver-name"] ?? EMPTYSTRING).replacingOccurrences(of: "+", with: " ")
//                        let amountStr = queryParameters["amount"] ?? EMPTYSTRING
//                        let messageStr = queryParameters["message"] ?? EMPTYSTRING
//                        let senderStr = queryParameters["sender-name"] ?? EMPTYSTRING

                        let iban = payURL?.iban
                        let xTaler = payURL?.xTaler ??
//                                   payURL?.host() ??
                                     String(localized: "unknown payment method")
                        let cryptocode = HStack {
                            Text(details.reservePub)
                                .monospacedDigit()
                                .accessibilityLabel("Cryptocode")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            CopyButton(textToCopy: details.reservePub, vertical: true)
                                .accessibilityLabel("Copy the cryptocode")
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
                                .accessibilityLabel("Payee")
                            CopyButton(textToCopy: receiverStr, vertical: true)
                                .accessibilityLabel("Copy the payee")
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
                                .accessibilityLabel("IBAN of the payee")
                            CopyButton(textToCopy: iban ?? EMPTYSTRING, vertical: true)
                                .accessibilityLabel("Copy the IBAN")
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
                                .accessibilityLabel("account of the payee")
                            CopyButton(textToCopy: xTaler, vertical: true)
                                .accessibilityLabel("Copy the account")
                                .disabled(false)
                        }   .padding(.top, -8)

                        let step1 = Text(minimalistic ? "**Step 1:** Copy+Paste this subject:"
                                  : "**Step 1:** Copy this code and paste it into the subject/purpose field in your banking app or bank website:")
                                        .multilineTextAlignment(.leading)
                        let mandatory = Text("This is mandatory, otherwise your money will not arrive in this wallet.")
                            .bold()
                            .multilineTextAlignment(.leading)
                            .listRowSeparator(.hidden)
                        let step2i = Text(minimalistic ? "**Step 2:** Copy+Paste payee and IBAN:"
                                   : "**Step 2:** If you don't already have it in your banking favorites list, then copy and paste payee and IBAN into the payee/IBAN fields in your banking app or website (and save it as favorite for the next time):")
                                        .multilineTextAlignment(.leading)
                                        .padding(.top)
                        let step2x = Text(minimalistic ? "**Step 2:** Copy+Paste payee and account:"
                                   : "**Step 2:** Copy and paste payee and account into the corresponding fields in your banking app or website:")
                                        .multilineTextAlignment(.leading)
                                        .padding(.top)
                        let step3 = Text(minimalistic ? "**Step 3:** Transfer \(amountStr)."
                                  : "**Step 3:** Finish the wire transfer of \(amountStr) in your banking app or website, then this withdrawal will proceed automatically. Depending on your bank the transfer can take from minutes to two working days, please be patient.")
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
                            Text(minimalistic ? "**Alternative:** Use this PayTo-Link:"
                                    : "**Alternative:** If your bank already supports PayTo, you can use this PayTo-Link instead:")
                                .multilineTextAlignment(.leading)
                                .padding(.top)
                                .listRowSeparator(.hidden)
                            HStack {
                                Text(verbatim: "|")       // only reason for this leading-aligned text is to get a nice full length listRowSeparator
                                    .accessibilityHidden(true)
                                    .foregroundColor(Color.clear)
//                              Spacer()
                                ShareButton(textToShare: payto)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .accessibilityLabel("Share the PayTo URL")
                                    .disabled(false)
//                              Spacer()
                            }   .listRowSeparator(.automatic)
                        }.id(listID)
                            .talerFont(.body)
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
