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
                    let specs = detail.currencySpecification
                    let amount = detail.transferAmount
                    let amountStr = amount?.formatted(specs: specs, isNegative: false, useISO: false) ?? ""
                    let bankName = detail.bankLabel
                    let a11yLabel = bankName != nil ? (bankName! + " " + amountStr) : amountStr
//            let _ = print(amountStr)
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
                        let amountStr = amount.formatted(isNegative: false, useISO: false)
//            let _ = print(amountStr)
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
            let amountNBS = amountStr.nbs
            let obtainNBS = obtainStr.nbs
            Text(minimalistic ? "Transfer \(amountNBS) to the Payment Service."
                              : "You need to transfer \(amountNBS) from your regular bank account to the Payment Service Provider to receive \(obtainNBS) as electronic cash in this wallet.")
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
    let stack: CallStack
    var common : TransactionCommon
    var details : WithdrawalDetails

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
    func validDetails(_ details: [WithdrawalExchangeAccountDetails]) -> [WithdrawalExchangeAccountDetails] {
        details.filter { detail in
            detail.status.lowercased() == "ok"
        }
    }

    var body: some View {
        if let accountDetails = details.exchangeCreditAccountDetails {
            let validDetails = validDetails(accountDetails)
            if validDetails.count > 0 {
                let account = validDetails[accountID]
                if let amount = account.transferAmount {
                    let specs = account.currencySpecification
                    let amountStr = amount.formatted(specs: specs, isNegative: false)
                    let obtainStr = common.amountRaw.formatted(isNegative: false)
//            let _ = print(amountStr, " | ", obtainStr)
                    if !minimalistic {
                        Text("The Payment Service Provider is waiting for your wire-transfer.")
                            .bold()
                            .multilineTextAlignment(.leading)
                            .listRowSeparator(.hidden)
                    }
                    if validDetails.count > 1 {
                        if validDetails.count > 3 { // too many for SegmentControl
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
                    let qrCodesForPayto = Group {
                        ForEach(qrCodeSpecs, id: \.self) { spec in
                            let specDetails = String("❗️\(spec.type)❗️\(spec.qrContent)❗️")
                            QRGeneratorView(text: spec.qrContent)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .accessibilityLabel("QR Code")
                                .listRowSeparator(.hidden)
                            CopyShare(textToCopy: spec.qrContent)
                                .disabled(false)
//                    .padding(.bottom)

//                            Text(specDetails)
//                                .listRowSeparator(.automatic)
                        }
                    }

                    let payURL = URL(string: payto)
                    if let queryParameters = payURL?.queryParameters {
                        let iban = payURL?.iban
                        let xTaler = payURL?.xTaler ??
//                                   payURL?.host() ??
                                     String(localized: "unknown payment method")
                        let wireDetails = ManualDetailsWireV(stack: stack.push(),
                                                           details: details,
                                                   queryParameters: queryParameters,
                                                              iban: iban,
                                                            xTaler: xTaler,
                                                         amountStr: amountStr,
                                                         obtainStr: obtainStr,
                                                           account: account)
                        Group {
                            NavigationLink(destination: wireDetails) {
                                Text(minimalistic ? "Instructions"
                                                  : "Wire transfer instructions")
                            }
                            Text(minimalistic ? "**Alternative:** Use this PayTo-Link:"
                                    : "**Alternative:** If your bank already supports PayTo, you can use this PayTo-Link instead:")
                                .multilineTextAlignment(.leading)
                                .padding(.top)
                                .listRowSeparator(.hidden)
                            let title = String(localized: "Share the PayTo URL", comment: "VoiceOver")
                            let minTitle = String(localized: "Share PayTo", comment: "mini")
                            ShareButton(textToShare: payto, title: minimalistic ? minTitle : title)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                .accessibilityLabel(Text(title))
                                    .disabled(false)
                            qrCodesForPayto
                        }.id(listID)
                            .talerFont(.body)
                            .task {
                                if let specs = try? await model.getQrCodesForPaytoM(payto) {
                                    qrCodeSpecs = specs ?? []
                                }
                            }
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
            ManualDetailsV(stack: CallStack("Preview"), common: common, details: details)
        }
    }
}
#endif
