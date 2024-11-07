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
    @Binding var value: Int
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
                    let amountStr = amount?.formatted(specs: specs, isNegative: false, useISO: false) ?? EMPTYSTRING
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
            if selectedAccount != value {
                withAnimation { selectedAccount = value }
            }
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
    @Binding var value: Int
    let accountDetails: [WithdrawalExchangeAccountDetails]
    let action: (Int) -> Void

    @State private var selected = 0

    var body: some View {
        Picker(title, selection: $selected) {
            ForEach(0..<accountDetails.count, id: \.self) { index in
                let detail = accountDetails[index]
                    if let amount = detail.transferAmount {
                        let amountStr = amount.formatted(specs: detail.currencySpecification,
                                                    isNegative: false, useISO: false)
//            let _ = print(amountStr)
                        if let bankName = detail.bankLabel {
                            Text(bankName + ":   " + amountStr)
                                .tag(index)
                        } else {
                            Text(amountStr)
                                .tag(index)
                        }
                    }
            }
        }
        .talerFont(.title3)
//        .pickerStyle(.menu)
        .onAppear() {
            withAnimation { selected = value }
        }
        .onChange(of: selected) { newValue in
            action(newValue)
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
                    let amountStr = common.amountRaw.formatted(specs: specs, isNegative: false)
                    let obtainStr = common.amountEffective.formatted(specs: specs, isNegative: false)
//            let _ = print(amountStr, " | ", obtainStr)
                    if !minimalistic {
                        Text("The payment service is waiting for your wire-transfer.")
                            .bold()
                            .multilineTextAlignment(.leading)
                            .listRowSeparator(.hidden)
                    }
                    if validDetails.count > 1 {
                        let picker = AccountPicker(title: String(localized: "Bank"),
                                                   value: $accountID,
                                          accountDetails: validDetails,
                                                  action: redraw)
                            .listRowSeparator(.hidden)
                        if validDetails.count > 3 { // too many for SegmentControl
                            picker.pickerStyle(.menu)
                        } else {
//                            picker.pickerStyle(.segmented)
                            SegmentControl(value: $accountID, accountDetails: validDetails, action: redraw)
                                .listRowSeparator(.hidden)
                        }
                    } else if let amount = account.transferAmount {
                        if let bankName = account.bankLabel {
                            Text(bankName + ":   " + amountStr)
//                        } else {
//                            Text(amountStr)
                        }
                    }
                    let payto = account.paytoUri
                    let payURL = URL(string: payto)
                    if let queryParameters = payURL?.queryParameters {
                        let iban = payURL?.iban
                        let xTaler = payURL?.xTaler ??
//                                   payURL?.host() ??
                                     String(localized: "unknown payment method")
                        let receiverStr = (queryParameters["receiver-name"] ?? EMPTYSTRING)
                                            .replacingOccurrences(of: "+", with: " ")
//                        let amountStr = queryParameters["amount"] ?? EMPTYSTRING
//                        let messageStr = queryParameters["message"] ?? EMPTYSTRING
//                        let senderStr = queryParameters["sender-name"] ?? EMPTYSTRING
                        let wireDetails = ManualDetailsWireV(stack: stack.push(),
                                                           details: details,
                                                       receiverStr: receiverStr,
                                                              iban: iban,
                                                            xTaler: xTaler,
                                                         amountStr: amountStr,
                                                         obtainStr: obtainStr,
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
                            if let iban {
                                Text(minimalistic ? "**Alternative:** Use this PayTo-Link:"
                                    : "**Alternative:** If your bank already supports PayTo, you can use this PayTo-Link instead:")
                                    .multilineTextAlignment(.leading)
                                    .padding(.top)
                                    .listRowSeparator(.hidden)
                                let title = String(localized: "Share the PayTo URL", comment: "VoiceOver")
                                let minTitle = String(localized: "Share PayTo", comment: "mini")
                                let textToShare = String("\(payto)\n\nIBAN: \(iban)\nReceiver: \(receiverStr)\nAmount: \(amountStr)\nSubject: \(details.reservePub)")
                                let _ = print(textToShare)
                                ShareButton(textToShare: textToShare, title: minimalistic ? minTitle : title)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .accessibilityLabel(Text(title))
                                    .disabled(false)
                                    .listRowSeparator(.hidden)
                            }
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
                                     scopes: [],
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
