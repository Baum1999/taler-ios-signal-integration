/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
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
    let feeLabel: String?
    let feeIsNotZero: Bool?             // nil = no fees at all, false = no fee for this tx
    let outgoing: Bool
    @Binding var amountToTransfer: Amount
    @Binding var summary: String
    @Binding var expireDays: UInt

    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var myFeeLabel: String = EMPTYSTRING
    @State private var transactionStarted: Bool = false
    @FocusState private var isFocused: Bool

    private func buttonTitle(_ amount: Amount) -> String {
        let amountWithCurrency = amount.formatted(scope, isNegative: false, useISO: true)
        return outgoing ? String(localized: "Send \(amountWithCurrency) now",
                                   comment: "amount with currency")
                        : String(localized: "Request \(amountWithCurrency)",
                                   comment: "amount with currency")
    }

    private func subjectTitle(_ amount: Amount) -> String {
        let amountStr = amount.formatted(scope, isNegative: false)
        return outgoing ? String(localized: "NavTitle_Send_AmountStr",
                              defaultValue: "Send \(amountStr)",
                                   comment: "NavTitle: Send 'amountStr'")
                        : String(localized: "NavTitle_Request_AmountStr",
                              defaultValue: "Request \(amountStr)",
                                   comment: "NavTitle: Request 'amountStr'")
    }

    @MainActor
    private func checkPeerPushDebit() async {
        if outgoing && feeLabel == nil {
            if let ppCheck = try? await model.checkPeerPushDebit(amountToTransfer, scope: scope) {
                if let feeAmount = p2pFee(ppCheck: ppCheck) {
                    let feeStr = feeAmount.formatted(scope, isNegative: false)
                    myFeeLabel = String(localized: "+ \(feeStr) fee")
                } else { myFeeLabel = EMPTYSTRING }
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
                if label.count > 0 {
                    Text(label)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(feeIsNotZero ? .red : WalletColors().secondary(colorScheme, colorSchemeContrast))
                        .talerFont(.body)
                }
            }
                if !minimalistic {
                    Text("Enter subject:")    // Purpose
                        .talerFont(.title3)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityRemoveTraits(.isStaticText)
                        .padding(.top)
                }
                Group { if #available(iOS 16.0, *) {
                    TextField(minimalistic ? "Subject" : EMPTYSTRING, text: $summary, axis: .vertical)
                        .submitLabel(.next)
                        .focused($isFocused)
                        .onChange(of: summary) { newValue in
                            guard isFocused else { return }
                            guard newValue.contains("\n") else { return }
                            isFocused = false
                            summary = newValue.replacing("\n", with: "")
                        }
                  } else {
                    TextField("Subject", text: $summary)
                        .submitLabel(.next)
                        .focused($isFocused)
                        .onChange(of: summary) { newValue in
                            guard isFocused else { return }
                            guard newValue.contains("\n") else { return }
                            isFocused = false
                            summary = newValue.replacingOccurrences(of: "\n", with: "")
                        }
                } } // Group for iOS16+ & iOS15
                    .talerFont(.title2)
                    .foregroundColor(WalletColors().fieldForeground)     // text color
                    .background(WalletColors().fieldBackground)
                    .textFieldStyle(.roundedBorder)
                    .onAppear {
                        if !UIAccessibility.isVoiceOverRunning {
                            symLog.log("dispatching kbd...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                isFocused = true        // make first responder - raise keybord
                                symLog.log("...kbd isFocused")
                            }
                        }
                    }
                Text(verbatim: "\(summary.count)/100")                          // maximum 100 characters
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .talerFont(.body)
                    .accessibilityValue(String(localized: "\(summary.count) characters of 100"))

                // TODO: compute max Expiration day from peerPushCheck to disable 30 (and even 7)
                SelectDays(selected: $expireDays, maxExpiration: THIRTYDAYS, outgoing: outgoing)
                    .disabled(false)
                    .padding(.bottom)

                let disabled = (expireDays == 0) || (summary.count < 1)    // TODO: check amountAvailable
            let destination = P2PReadyV(stack: stack.push(),
                                        scope: scope,
                                      summary: summary,
                                   expireDays: expireDays,
                                     outgoing: outgoing,
                             amountToTransfer: amountToTransfer,
                           transactionStarted: $transactionStarted)
            NavigationLink(destination: destination) {
                Text(buttonTitle(amountToTransfer))
            }
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
                .disabled(disabled)
                .accessibilityHint(disabled ? String(localized: "enabled when subject and expiration are set") : EMPTYSTRING)
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
