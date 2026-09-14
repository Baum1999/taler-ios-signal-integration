/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
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
        if let effective = ppCheck.amountEffective {
            let fee = try effective - ppCheck.amountRaw
            return fee
        }
    } catch {}
    return nil
}

struct P2PSubjectV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let cash: OIMcash
    let scope: ScopeInfo
    let available: Amount
    let feeLabel: (String, String)?
    let feeIsNotZero: Bool?             // nil = no fees at all, false = no fee for this tx
    let outgoing: Bool
    @Binding var amountToTransfer: Amount
    @Binding var summary: String
    @Binding var iconID: String?
    @Binding var expireDays: UInt

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var myFeeLabel: (String, String) = (EMPTYSTRING, EMPTYSTRING)
    @State private var defaultExpiration: Duration? = nil
    @State private var maxExpirationDate: Timestamp? = nil
    @State private var transactionStarted: Bool = false
    @State private var sendOrRequest: Bool = false
    @FocusState private var isFocused: Bool
    @Namespace var namespace

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
                defaultExpiration = ppCheck.defaultExpiration
                maxExpirationDate = ppCheck.maxExpirationDate
            } else {
                print("❗️ checkPeerPushDebitM failed")
            }
        }
    }

    var maxExpirationHours: UInt64 {
        if let duration = try? maxExpirationDate?.duration() {
            return duration.toHours()
        }
        return 0
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog(amountToTransfer.readableDescription)       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let scrollView = ScrollView { VStack (alignment: .leading, spacing: 6) {
            if let feeIsNotZero {       // don't show fee if nil
                let label = feeLabel ?? myFeeLabel
                if !label.0.isEmpty {
                    Text(label.0)
                        .accessibilityLabel(label.1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(WalletColors().secondary2(colorScheme, colorSchemeContrast))
                        .talerFont(.body)
                }
            }
            let enterSubject = String(localized: "Enter subject", comment: "Purpose, a11y")
            let enterColon = String("\(enterSubject):")
            if !minimalistic {
                Text(enterSubject)    // Purpose
                    .talerFont(.title3)
                    .accessibilityHidden(true)
                    .padding(.top)
            }
            Group { if #available(iOS 16.4, *) {
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
                    guard newValue.contains(LINEFEED) else { return }
                    isFocused = false
                    summary = newValue.replacingOccurrences(of: LINEFEED, with: EMPTYSTRING)
                }
                .foregroundColor(WalletColors().fieldForeground)     // text color
                .background(WalletColors().fieldBackground)
                .textFieldStyle(.roundedBorder)
            let numChars = summary.count
            Text(verbatim: "\(numChars)/100")                          // maximum 100 characters
                .frame(maxWidth: .infinity, alignment: .trailing)
                .talerFont(.body)
                .accessibilityLabel(EMPTYSTRING)
                .accessibilityValue(String(localized: "\(numChars) characters of 100"))

            // TODO: compute max Expiration day from peerPushCheck to disable 30 (and even 7)
            SelectDays(selected: $expireDays, maxExpirationHours: maxExpirationHours,
                       defaultExpirationHours: defaultExpiration?.toHours() ?? 28*24, outgoing: outgoing)
                .padding(.bottom)

            let disabled = (expireDays == 0)    // || (numChars < 1)    // TODO: check amountAvailable
            let destination = P2PReadyV(stack: stack.push(),
                                        scope: scope,
                                      summary: numChars > 0 ? summary : placeHolder,
                                       iconID: iconID,
                                   expireDays: expireDays,
                                     outgoing: outgoing,
                             amountToTransfer: amountToTransfer,
                           transactionStarted: $transactionStarted)
            let actions = Group {
                NavLink($sendOrRequest) { destination }
            }

            let buttonTitle = buttonTitle(amountToTransfer)
            Button(buttonTitle.0) {
                sendOrRequest = true
            }
                .background(actions)
                .accessibilityLabel(buttonTitle.1)
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
                .disabled(disabled)
                .accessibilityHint(disabled ? String(localized: "enabled when subject and expiration are set", comment: "a11y")
                                            : EMPTYSTRING)
        }.padding(.horizontal) } // ScrollVStack
//        .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
//        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle(subjectTitle(amountToTransfer))
        .background(FullBackground())
        .task(id: amountToTransfer.value) { await checkPeerPushDebit() }
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_SUBJECT, stack: stack.push())
//            print("❗️ P2PSubjectV onAppear")
        }
        .onDisappear {
//            print("❗️ P2PSubjectV onDisappear")
        }

        scrollView
#if OIM
            .overlay { if #available(iOS 16.4, *) {
                if controller.oimModeActive {
                    OIMSubjectView(stack: stack.push(),
                                    cash: cash,
                               available: available,
                        amountToTransfer: $amountToTransfer,
                            selectedGoal: $iconID,
                         fwdButtonTapped: $sendOrRequest)
                    .environmentObject(NamespaceWrapper(namespace))             // keep OIMviews apart
                }
            } }
#endif
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
