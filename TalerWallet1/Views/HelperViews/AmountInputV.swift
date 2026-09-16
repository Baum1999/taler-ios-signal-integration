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

struct ComputeFeeResult {
    let insufficient: Bool
    let feeAmount: Amount?
    let feeStr: (String, String)
    let numCoins: Int?

    static func zero() -> ComputeFeeResult {
        ComputeFeeResult(insufficient: false,
                            feeAmount: nil,
                               feeStr: (EMPTYSTRING, EMPTYSTRING),
                             numCoins: 0)
    }
    static func insufficient() -> ComputeFeeResult {
        ComputeFeeResult(insufficient: true,
                            feeAmount: nil,
                               feeStr: (EMPTYSTRING, EMPTYSTRING),
                             numCoins: -1)
    }
}
// MARK: -
struct AmountInputV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let scope: ScopeInfo?
    @Binding var amountAvailable: Amount
    let amountLabel: String?
    let a11yLabel: String
    @Binding var amountToTransfer: Amount
    let amountLastUsed: Amount
    let wireFee: Amount?
    @Binding var summary: String
//    @Binding var insufficient: Bool
//    @Binding var feeAmount: Amount?
    let shortcutAction: ((_ amount: Amount) -> Void)?
    let buttonAction: () -> Void
//    let feeIsNegative: Bool
    let isIncoming: Bool
    let computeFee: ((_ amount: Amount) async -> ComputeFeeResult?)?

    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    @State private var feeAmount: Amount? = nil
    @State private var feeStr = (EMPTYSTRING, EMPTYSTRING)
    @State private var numCoins: Int?
    @State private var coreInsufficient: Bool = false    // wallet-core's own verdict

    struct Flags {
        let insufficient: Bool
        let disabled: Bool
    }

    func checkAvailable(_ coinData: CoinData) -> Flags {
        let isZero = amountToTransfer.isZero && !developerMode
        // wallet-core's verdict is authoritative and comes first: it accounts for fees,
        // age restrictions, per-exchange limits and pending refreshes, none of which a
        // local `amountToTransfer > amountAvailable` can see.
        if coreInsufficient {
            return Flags(insufficient: true, disabled: true)
        }
        if !amountAvailable.isZero {
            do {
                let insufficient: Bool
//                if let feeAmount {
//                    if feeIsNegative {
//                        insufficient = try amountToTransfer > amountAvailable
//                    } else {
//                        insufficient = try (amountToTransfer + feeAmount) > amountAvailable
//                    }
//                } else {
                    insufficient = try amountToTransfer > amountAvailable
//                }
                let invalid = coinData.invalid  && !developerMode  // P2P ==> zero not supported
                let disabled = insufficient || isZero || invalid || coinData.tooMany
                return Flags(insufficient: insufficient, disabled: disabled)
            } catch {
                // TODO: error Amounts don't match
                symLog.log("❗️Cannot compare amountAvailable.\(amountAvailable.currencyStr) to amountToTransfer.\(amountToTransfer.currencyStr))")
            }
        }
        // No usable local bound (an incoming amount, or a caller that never sets
        // amountAvailable — see PayTemplateScan.swift:36). Deliberately NOT failing closed
        // here: those callers still get the wallet-core verdict above, and failing closed
        // would permanently disable a pay-template that has no availability to compare to.
        return Flags(insufficient: false, disabled: isZero || coinData.invalid || coinData.tooMany)
    }

    var body: some View {
        let currency = amountToTransfer.currencyStr
        let coinData = CoinData(coins: numCoins, fee: feeAmount)
        let flags = checkAvailable(coinData)
        let hint = String(localized: "enabled when amount is non-zero", comment: "a11y")
        ScrollView { VStack(alignment: .trailing) {
            CurrencyInputView(scope: scope,
                             amount: $amountToTransfer,
                     amountLastUsed: amountLastUsed,
                          available: isIncoming ? nil : amountAvailable,
                       insufficient: flags.insufficient,
                              title: amountLabel,
                          a11yTitle: a11yLabel,
                     shortcutAction: shortcutAction)
//                .accessibility(sortPriority: 2)
            QuiteSomeCoins(scope: scope,
                        coinData: coinData,
                   shouldShowFee: true,       // TODO: set to false if we never charge withdrawal fees
                   feeIsNegative: isIncoming)
            Button("Next") { buttonAction() }
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: flags.disabled))
                .disabled(flags.disabled)
                .accessibilityHint(flags.disabled ? hint : EMPTYSTRING)
                .padding(.bottom, 333)
        }.padding(.horizontal) } // ScrollVStack
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FullBackground())
        .task(id: amountToTransfer.value) {
            // re-compute the fees on every tapped digit or backspace
            if let computeFee {
                symLog.log(".task \(amountToTransfer.value)")
                if let result: ComputeFeeResult = await computeFee(amountToTransfer) {
                    symLog.log("computeFee() finished")
                    feeStr = result.feeStr
                    coreInsufficient = result.insufficient
                    feeAmount = result.feeAmount
                    numCoins = result.numCoins
                } else {
                    // No verdict this round - keep the previous one rather than silently
                    // treating an unanswered question as "you can afford it".
                    symLog.log("computeFee() failed ❗️") //  \(error)")
                }
            }
        }
    }
}
