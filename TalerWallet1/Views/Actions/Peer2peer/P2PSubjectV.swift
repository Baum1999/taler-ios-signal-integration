/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

func p2pFee(ppCheck: CheckPeerPushDebitResponse) -> Amount? {
    do {
        // Outgoing: fee = effective - raw
        let fee = try ppCheck.amountEffective - ppCheck.amountRaw
        return fee
    } catch {}
    return nil
}

struct P2PSubjectV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scope: ScopeInfo
    let feeLabel: (String, String)?
    let feeIsNotZero: Bool?             // nil = no fees at all, false = no fee for this tx
    let outgoing: Bool
    @Binding var amountToTransfer: Amount
    @Binding var summary: String
    @Binding var expireDays: UInt

    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var myFeeLabel: (String, String) = (EMPTYSTRING, EMPTYSTRING)
    @State private var transactionStarted: Bool = false
    @FocusState private var isFocused: Bool

    private func sendTitle(_ amountWithCurrency: String) -> String {
        String(localized: "Send \(amountWithCurrency) now",
                 comment: "amount with currency")
    }
    private func requTitle(_ amountWithCurrency: String) -> String {
        String(localized: "Request \(amountWithCurrency)",
                 comment: "amount with currency")
    }

    private func buttonTitle(_ amount: Amount) -> (String, String) {
        let amountWithCurrency = amount.formatted(scope, isNegative: false, useISO: true)
        return outgoing ? (sendTitle(amountWithCurrency.0), sendTitle(amountWithCurrency.1))
                        : (requTitle(amountWithCurrency.0), requTitle(amountWithCurrency.1))
    }

    private var placeHolder: String {
        return outgoing ? String(localized: "Sent with GNU TALER")
                        : String(localized: "Requested with GNU TALER")
    }

    private func subjectTitle(_ amount: Amount) -> String {
        let amountStr = amount.formatted(scope, isNegative: false)
        return outgoing ? String(localized: "NavTitle_Send_AmountStr",
                              defaultValue: "Send \(amountStr.0)",
                                   comment: "NavTitle: Send 'amountStr'")
                        : String(localized: "NavTitle_Request_AmountStr",
                              defaultValue: "Request \(amountStr.0)",
                                   comment: "NavTitle: Request 'amountStr'")
    }

    @MainActor
    private func checkPeerPushDebit() async {
        if outgoing && feeLabel == nil {
            if let ppCheck = try? await model.checkPeerPushDebit(amountToTransfer, scope: scope) {
                if let feeAmount = p2pFee(ppCheck: ppCheck) {
                    let feeStr = feeAmount.formatted(scope, isNegative: false)
                    myFeeLabel = (String(localized: "+ \(feeStr.0) fee"),
                                  String(localized: "+ \(feeStr.1) fee"))
                } else { myFeeLabel = (EMPTYSTRING, EMPTYSTRING) }
            } else {
                print("❗️ checkPeerPushDebitM failed")

            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(amountToTransfer.readableDescription)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        ScrollView { VStack (alignment: .leading, spacing: 6) {
            if let feeIsNotZero {       // don't show fee if nil
                let label = feeLabel ?? myFeeLabel
                if label.0.count > 0 {
                    Text(label.0)
                        .accessibilityLabel(label.1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                        .talerFont(.body)
                }
            }
            let enterSubject = String(localized: "Enter subject")
            let enterColon = String("\(enterSubject):")
            if !minimalistic {
                Text(enterSubject)    // Purpose
                    .talerFont(.title3)
                    .accessibilityHidden(true)
                    .padding(.top)
            }
            Group { if #available(iOS 16.0, *) {
                TextField(placeHolder, text: $summary, axis: .vertical)
            } else {
                TextField(placeHolder, text: $summary)
            } }
                .talerFont(.title2)
                .accessibilityLabel(enterColon)
                .submitLabel(.next)
                .focused($isFocused)
                .onChange(of: summary) { newValue in
                    guard isFocused else { return }
                    guard newValue.contains("\n") else { return }
                    isFocused = false
                    summary = newValue.replacingOccurrences(of: LINEFEED, with: EMPTYSTRING)
                }
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .textFieldStyle(.roundedBorder)
            Text(verbatim: "\(summary.count)/100")                          // maximum 100 characters
                .frame(maxWidth: .infinity, alignment: .trailing)
                .talerFont(.body)
                .accessibilityLabel(EMPTYSTRING)
                .accessibilityValue(String(localized: "\(summary.count) characters of 100"))

                // TODO: compute max Expiration day from peerPushCheck to disable 30 (and even 7)
                SelectDays(selected: $expireDays, maxExpiration: THIRTYDAYS, outgoing: outgoing)
                    .disabled(false)
                    .padding(.bottom)

                let disabled = (expireDays == 0)    // || (summary.count < 1)    // TODO: check amountAvailable
            let destination = P2PReadyV(stack: stack.push(),
                                        scope: scope,
                                      summary: summary.count > 0 ? summary : placeHolder,
                                   expireDays: expireDays,
                                     outgoing: outgoing,
                             amountToTransfer: amountToTransfer,
                           transactionStarted: $transactionStarted)
            NavigationLink(destination: destination) {
                let buttonTitle = buttonTitle(amountToTransfer)
                Text(buttonTitle.0)
                    .accessibilityLabel(buttonTitle.1)
            }
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
                .disabled(disabled)
                .accessibilityHint(disabled ? String(localized: "enabled when subject and expiration are set", comment: "VoiceOver")
                                            : EMPTYSTRING)
        }.padding(.horizontal) } // ScrollVStack
//        .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
        .navigationTitle(subjectTitle(amountToTransfer))
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .task(id: amountToTransfer.value) { await checkPeerPushDebit() }
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_SUBJECT, stack: stack.push())
//            print("❗️ P2PSubjectV onAppear")
        }
        .onDisappear {
//            print("❗️ P2PSubjectV onDisappear")
        }
    }
}
// MARK: -
#if DEBUG
//struct SendPurpose_Previews: PreviewProvider {
//    static var previews: some View {
//        @State var summary: String = EMPTYSTRING
//        @State var expireDays: UInt = 0
//        let amount = Amount(currency: LONGCURRENCY, integer: 10, fraction: 0)
//        SendPurpose(amountAvailable: amount,
//                   amountToTransfer: 543,
//                                fee: "0,43",
//                            summary: $summary,
//                         expireDays: $expireDays)
//    }
//}
#endif
