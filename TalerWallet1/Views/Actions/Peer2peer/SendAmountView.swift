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

// Called when tapping [􁉇Send]
struct SendAmountView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let balance: Balance
    @Binding var amountLastUsed: Amount
    @Binding var amountToTransfer: Amount
    @Binding var amountAvailable: Amount
    @Binding var summary: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State var peerPushCheck: CheckPeerPushDebitResponse? = nil
    @State private var expireDays = SEVENDAYS
    @State private var insufficient = false
//    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING
    @State private var buttonSelected = false
    @State private var shortcutSelected = false
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var exchange: Exchange? = nil                                // wg. noFees

    @State private var scopeInfo: ScopeInfo? = nil

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        shortcutSelected = true
    }
    private func buttonAction() { buttonSelected = true }

    public static func navTitle(_ currency: String, _ condition: Bool = false) -> String {
        condition ? String(localized: "NavTitle_Send_Currency",
                        defaultValue: "Send \(currency)",
                             comment: "NavTitle: Send 'currency'")
                  : String(localized: "NavTitle_Send",
                        defaultValue: "Send",
                             comment: "NavTitle: Send")
    }

    private func feeLabel(_ feeString: String) -> String {
        feeString.count > 0 ? String(localized: "+ \(feeString) fee")
                            : EMPTYSTRING
    }

    private func fee(raw: Amount, effective: Amount) -> Amount? {
        do {     // Outgoing: fee = effective - raw
            let fee = try effective - raw
            return fee
        } catch {}
        return nil
    }

    private func feeIsNotZero() -> Bool? {
        if let hasNoFees = exchange?.noFees {
            if hasNoFees {
                return nil      // this exchange never has fees
            }
        }
        return peerPushCheck == nil ? false
                                    : true // TODO: !(feeAmount?.isZero ?? false)
    }

    private func computeFee(_ amount: Amount) async -> ComputeFeeResult? {
        if amount.isZero {
            return ComputeFeeResult.zero()
        }
        let insufficient = (try? amount > amountAvailable) ?? true
        if insufficient {
            return ComputeFeeResult.insufficient()
        }
        if let scopeInfo {
            do {
                let ppCheck = try await model.checkPeerPushDebitM(amount, scope: scopeInfo, viewHandles: true)
                let raw = ppCheck.amountRaw
                let effective = ppCheck.amountEffective
                if let fee = fee(raw: raw, effective: effective) {
                    feeStr = fee.formatted(scopeInfo, isNegative: false)
                    symLog.log("Fee = \(feeStr)")
                    let insufficient = (try? effective > amountAvailable) ?? true

                    peerPushCheck = ppCheck
                    let feeLabel = feeLabel(feeStr)
//                    announce("\(amountVoiceOver), \(feeLabel)")
                    return ComputeFeeResult(insufficient: insufficient,
                                               feeAmount: fee,
                                                  feeStr: feeLabel,
                                                numCoins: nil)
                } else {
                    peerPushCheck = nil
                }
            } catch {
                // handle cancel, errors
                symLog.log("❗️ \(error), \(error.localizedDescription)")
                switch error {
                    case let walletError as WalletBackendError:
                        switch walletError {
                            case .walletCoreError(let wError):
                                if wError?.code == 7027 {
                                    return ComputeFeeResult.insufficient()
                                }
                            default: break
                        }
                    default: break
                }
            }
        }
        return nil
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if scopeInfo != nil {
                let availableStr = amountAvailable.formatted(scopeInfo, isNegative: false)
//              let availableA11y = amountAvailable.formatted(currencyInfo, isNegative: false, useISO: true, a11y: ".")
//              let amountVoiceOver = amountToTransfer.formatted(currencyInfo, isNegative: false)
//              let insufficientLabel2 = String(localized: "but you only have \(availableStr) to send.")

                let inputDestination = P2PSubjectV(stack: stack.push(),
                                                   scope: scopeInfo!,
                                                feeLabel: feeLabel(feeStr),
                                            feeIsNotZero: feeIsNotZero(),
                                                outgoing: true,
                                        amountToTransfer: $amountToTransfer,    // from the textedit
                                                 summary: $summary,
                                              expireDays: $expireDays)
                let shortcutDestination = P2PSubjectV(stack: stack.push(),
                                                      scope: scopeInfo!,
                                                   feeLabel: nil,
                                               feeIsNotZero: feeIsNotZero(),
                                                   outgoing: true,
                                           amountToTransfer: $amountShortcut,   // from the tapped shortcut button
                                                    summary: $summary,
                                                 expireDays: $expireDays)
                let actions = Group {
                    NavLink($buttonSelected) { inputDestination }
                    NavLink($shortcutSelected) { shortcutDestination }
                }
                AmountInputV(stack: stack.push(),
                             scope: scopeInfo,
                   amountAvailable: $amountAvailable,
                       amountLabel: nil,        // will use "Available: xxx", trailing
                  amountToTransfer: $amountToTransfer,
                    amountLastUsed: amountLastUsed,
                           wireFee: nil,
                           summary: $summary,
                    shortcutAction: shortcutAction,
                      buttonAction: buttonAction,
                     feeIsNegative: false,
                        computeFee: computeFee)
                .background(actions)
            } else {    // must have $some view, otherwise .task will NOT run
                Text(" ")
            }
        } // Group
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_SEND, stack: stack.push())
            symLog.log("❗️ onAppear")
        }
        .onDisappear {
            symLog.log("❗️ onDisappear")
        }
        .task(id: balance) { // getMaxPeerPushDebit on first appearance
            let scope = balance.scopeInfo
            symLog.log("❗️ task \(scope.currency)")

            if let available = try? await model.getMaxPeerPushDebitAmountM(scope, viewHandles: true) {
                amountAvailable = available
            } else {
                amountAvailable = Amount.zero(currency: scope.currency)
            }
            scopeInfo = scope
        }
//        .task(id: amountToTransfer.value) {
//            if exchange == nil {
//                if let url = scopeInfo.url {
//                    exchange = try? await model.getExchangeByUrl(url: url)
//                }
//            }
//            do {
//                insufficient = try amountToTransfer > amountAvailable
//            } catch {
//                print("Yikes❗️ insufficient failed❗️")
//                insufficient = true
//            }
//
//            if insufficient {
//                announce("\(amountVoiceOver), \(insufficientLabel2)")
//            } else if amountToTransfer.isZero {
//                feeStr = EMPTYSTRING
//            } else {
//                if let ppCheck = try? await model.checkPeerPushDebitM(amountToTransfer) {
//                // TODO: set from exchange
////                agePicker.setAges(ages: peerPushCheck?.ageRestrictionOptions)
//                    if let feeAmount = fee(ppCheck: ppCheck) {
//                        feeStr = feeAmount.formatted(currencyInfo, isNegative: false)
//                        let feeLabel = feeLabel(feeStr)
//                        announce("\(amountVoiceOver), \(feeLabel)")
//                    } else {
//                        feeStr = EMPTYSTRING
//                        announce(amountVoiceOver)
//                    }
//                    peerPushCheck = ppCheck
//                } else {
//                    peerPushCheck = nil
//                }
//            }
//        }
    } // body
}
