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

// Called when tapping "Send Coins" in the balances list
struct SendAmountV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let balances: [Balance]
    @Binding var selectedBalance: Balance?      // selected balance when the action button is tapped in Transactions
    @Binding var amountToTransfer: Amount
    @Binding var summary: String
    let cameraAction: () -> Void

    @State private var balanceIndex = 0
    @State private var nonZeroBalances: [Balance] = []
    @State private var balance: Balance? = nil      // nil only when (balances / nonZeroBalances) == []

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
#endif
//        nonZeroBalances.count > 0
//        let balance = selectedBalance ?? nonZeroBalances[balanceIndex]
        let sendAmountView = ScrollView {
            let count = nonZeroBalances.count
            if let selectedBalance {
                let urlOrCurrency = selectedBalance.scopeInfo.url?.trimURL
                                 ?? selectedBalance.scopeInfo.currency
                let amount = selectedBalance.available
                let formattedAmount = amount.formatted(isNegative: false, useISO: false)
                let label = String("\(urlOrCurrency):\t\(formattedAmount.nbs)")
                Text(label)
//                    .padding(.leading)
                    .talerFont(.title3)
            } else if count > 0 {
                ScopePicker(value: $balanceIndex, balances: nonZeroBalances) { index in
                    balanceIndex = index
                    balance = nonZeroBalances[index]
                }
            }
            SendAmountContent(stack: stack.push(),
                            balance: $balance,
                       balanceIndex: $balanceIndex,
                   amountToTransfer: $amountToTransfer,
                            summary: $summary,
                       cameraAction: cameraAction)
        } // ScrollView
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
//        .scrollBounceBehavior(.basedOnSize)  needs iOS 16.4
            .task {
                if selectedBalance == nil {
                    nonZeroBalances = Balance.nonZeroBalances(balances)
                    let count = nonZeroBalances.count
                    if balanceIndex >= count {
                        balanceIndex = 0
                    }
                    if count > 0 {
                        balance = nonZeroBalances[balanceIndex]
                    } else {
                        balance = nil
                    }
                } else {
                    balance = selectedBalance
                }
            }

        if #available(iOS 16.0, *) {
            sendAmountView.toolbar(.hidden, for: .tabBar)
        } else {
            sendAmountView
        }
    }
}
// MARK: -
struct SendAmountContent: View {
    private let symLog = SymLogV()
    let stack: CallStack
    @Binding var balance: Balance?
    @Binding var balanceIndex: Int
    @Binding var amountToTransfer: Amount
    @Binding var summary: String
    let cameraAction: () -> Void

    // TODO: call getMaxPeerPushDebitAmountM

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State var peerPushCheck: CheckPeerPushDebitResponse? = nil
    @State private var expireDays = SEVENDAYS
    @State private var insufficient = false
//    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING
    @State private var buttonSelected = false
    @State private var shortcutSelected = false
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var amountAvailable = Amount.zero(currency: EMPTYSTRING)     // GetMaxPeerPushAmount
    @State private var exchange: Exchange? = nil                                // wg. noFees

    @State private var currencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var currencyName = UNKNOWN
    @State private var currencySymbol = UNKNOWN
    @State private var scopeInfo: ScopeInfo = ScopeInfo.zero()

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        shortcutSelected = true
    }
    private func buttonAction() { buttonSelected = true }

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

    private func computeFeeSend(_ amount: Amount) async -> ComputeFeeResult? {
        if amount.isZero {
            return ComputeFeeResult.zero()
        }
        let insufficient = (try? amount > amountAvailable) ?? true
        if insufficient {
            return ComputeFeeResult.insufficient()
        }
        do {
            let ppCheck = try await model.checkPeerPushDebitM(amount, scope: scopeInfo, viewHandles: true)
            let raw = ppCheck.amountRaw
            let effective = ppCheck.amountEffective
            if let fee = fee(raw: raw, effective: effective) {
                feeStr = fee.formatted(currencyInfo, isNegative: false)
                symLog.log("Fee = \(feeStr)")
                let insufficient = (try? effective > amountAvailable) ?? true

                peerPushCheck = ppCheck
                let feeLabel = feeLabel(feeStr)
//                announce("\(amountVoiceOver), \(feeLabel)")
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
        return nil
    }

    var body: some View {
#if true //PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let navTitle = String(localized: "NavTitle_Send",
                           defaultValue: "Send",
                                comment: "NavTitle: Send")
        Group {
            if let balance {
                let scopeInfo = balance.scopeInfo
                let availableStr = amountAvailable.formatted(currencyInfo, isNegative: false)
                let amountVoiceOver = amountToTransfer.formatted(currencyInfo, isNegative: false)
                let insufficientLabel2 = String(localized: "but you only have \(availableStr) to send.")

                let inputDestination = P2PSubjectV(stack: stack.push(),
                                                   scope: scopeInfo,
                                            currencyInfo: $currencyInfo,
                                                feeLabel: feeLabel(feeStr),
                                            feeIsNotZero: feeIsNotZero(),
                                                outgoing: true,
                                        amountToTransfer: $amountToTransfer,    // from the textedit
                                                 summary: $summary,
                                              expireDays: $expireDays)
                let shortcutDestination = P2PSubjectV(stack: stack.push(),
                                                      scope: scopeInfo,
                                               currencyInfo: $currencyInfo,
                                                   feeLabel: nil,
                                               feeIsNotZero: feeIsNotZero(),
                                                   outgoing: true,
                                           amountToTransfer: $amountShortcut,   // from the tapped shortcut button
                                                    summary: $summary,
                                                 expireDays: $expireDays)
                Group {
                    let amountLabel = minimalistic ? String(localized: "Amount:")
                                                   : String(localized: "Amount to send:")
                    AmountInputV(stack: stack.push(),
                          currencyInfo: $currencyInfo,
                       amountAvailable: $amountAvailable,
                           amountLabel: amountLabel,
                      amountToTransfer: $amountToTransfer,
                               wireFee: nil,
                               summary: $summary,
                        shortcutAction: shortcutAction,
                          buttonAction: buttonAction,
                         feeIsNegative: false,
                            computeFee: computeFeeSend)
                    .background(NavigationLink(destination: shortcutDestination, isActive: $shortcutSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                        ) // shortcutDestination
                    .background(NavigationLink(destination: inputDestination, isActive: $buttonSelected)
                            { EmptyView() }.frame(width: 0).opacity(0).hidden()
                        ) // inputDestination
                }
            } else {    // no balance - Yikes
                Text("No balance. There seems to be a problem with the database...")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .navigationTitle(navTitle)
        .task {
            do {
                let amount = try await model.getMaxPeerPushDebitAmountM(amountToTransfer.currencyStr,
                                                                        scope: scopeInfo, viewHandles: true)
                amountAvailable = amount
            } catch {
                amountAvailable = Amount.zero(currency: amountToTransfer.currencyStr)
            }
        }
        .onAppear {
            DebugViewC.shared.setViewID(VIEW_P2P_SEND, stack: stack.push())
            // if we set >> controller.frontendState = -1 << here, then becomeFirstResponder won't work!
            symLog.log("❗️ \(navTitle) onAppear")
        }
        .onDisappear {
            symLog.log("❗️ \(navTitle) onDisappear")
        }
        .navigationBarItems(trailing: QRButton(action: cameraAction))
        .task(id: balanceIndex + (1000 * controller.currencyTicker)) {
            if let balance {
                scopeInfo = balance.scopeInfo
                let currency = scopeInfo.currency
                amountAvailable = balance.available
                amountToTransfer.setCurrency(currency)
                currencyInfo = controller.info(for: currency, controller.currencyTicker)
                currencyName = currencyInfo.scope.currency
                currencySymbol = currencyInfo.altUnitSymbol ?? currencyInfo.specs.name
            }
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
    }
}
// MARK: -
#if DEBUG
fileprivate struct Preview_Content: View {
    @State private var amountToPreview = Amount(currency: DEMOCURRENCY, cent: 510)
    @State private var summary: String = ""
    @State private var currencyInfoL: CurrencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
    @State private var noBalance: Balance? = nil

    private func checkCameraAvailable() -> Void {
        // Open Camera when QR-Button was tapped
    }
    var body: some View {
        let amount = Amount(currency: DEMOCURRENCY, cent: 1000)
        let pending = Amount(currency: DEMOCURRENCY, cent: 0)
        let currencyInfo = CurrencyInfo.zero(DEMOCURRENCY)
        let exchange2 = Exchange(exchangeBaseUrl: ARS_EXP_EXCHANGE,
                                       masterPub: "masterPub",
                                       scopeInfo: currencyInfo.scope,
                                       paytoUris: [],
                                       tosStatus: .proposed,
                             exchangeEntryStatus: .ephemeral,
                            exchangeUpdateStatus: .ready,
                           ageRestrictionOptions: [])
        let scopeInfo = ScopeInfo(type: .exchange, url: DEMOEXCHANGE, currency: DEMOCURRENCY)
        let balance = Balance(scopeInfo: scopeInfo,
                              available: amount,
                        pendingIncoming: pending,
                        pendingOutgoing: pending,
                                  flags: [])
        SendAmountV(stack: CallStack("Preview"),
                 balances: [balance],
          selectedBalance: $noBalance,
         amountToTransfer: $amountToPreview,
                  summary: $summary,
             cameraAction: checkCameraAvailable)
    }
}

fileprivate struct Previews: PreviewProvider {
    @MainActor
    struct StateContainer: View {
        @StateObject private var controller = Controller.shared
        var body: some View {
            Preview_Content()
                .environmentObject(controller)
        }
    }
    static var previews: some View {
        StateContainer()
    }
}
#endif
