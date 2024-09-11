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

struct ComputeFeeResult {
    let insufficient: Bool
    let feeAmount: Amount?
    let feeStr: String
    let numCoins: Int?

    static func zero() -> ComputeFeeResult {
        ComputeFeeResult(insufficient: false,
                            feeAmount: nil,
                               feeStr: EMPTYSTRING,
                             numCoins: 0)
    }
    static func insufficient() -> ComputeFeeResult {
        ComputeFeeResult(insufficient: true,
                            feeAmount: nil,
                               feeStr: EMPTYSTRING,
                             numCoins: -1)
    }
}

struct AmountInputV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    @Binding var currencyInfo: CurrencyInfo

    @Binding var amountAvailable: Amount
    let amountLabel: String
    @Binding var amountToTransfer: Amount
    let wireFee: Amount?
    @Binding var summary: String
//    @Binding var insufficient: Bool
//    @Binding var feeAmount: Amount?
    let shortcutAction: ((_ amount: Amount) -> Void)?
    let buttonAction: () -> Void
    let feeIsNegative: Bool
    let computeFee: ((_ amount: Amount) async -> ComputeFeeResult?)?

    @EnvironmentObject private var controller: Controller
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING
    @State private var numCoins: Int?

    struct Flags {
        let insufficient: Bool
        let disabled: Bool
    }

    func checkAvailable(_ coinData: CoinData) -> Flags {
        let isZero = amountToTransfer.isZero
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
                let disabled = insufficient || isZero || coinData.invalid || coinData.tooMany
                return Flags(insufficient: insufficient, disabled: disabled)
            } catch {
                // TODO: error Amounts don't match
            }
        }
        return Flags(insufficient: false, disabled: isZero)
    }

    var body: some View {
        let currency = amountToTransfer.currencyStr
//        let insufficientLabel = String(localized: "You don't have enough \(currency).")
        let available = amountAvailable.isZero ? nil
                                               : amountAvailable.formatted(currencyInfo, isNegative: false)
        VStack(alignment: .trailing) {
            if summary.count > 0 {
                Text(summary)
                    .talerFont(.body)
                    .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                    .padding(4)
            }
            CurrencyInputView(currencyInfo: $currencyInfo,
                                    amount: $amountToTransfer,
                                 available: amountAvailable,
                                     title: amountLabel,
                            shortcutAction: shortcutAction)
//                .accessibility(sortPriority: 2)

            let coinData = CoinData(coins: numCoins, fee: feeAmount)
            QuiteSomeCoins(currencyInfo: $currencyInfo,
//                        amountEffective: amountEffective,
                               currency: currency,
                               coinData: coinData,
                          shouldShowFee: true,       // TODO: set to false if we never charge withdrawal fees
                          feeIsNegative: feeIsNegative)
            let flags = checkAvailable(coinData)
            Button("Next") { buttonAction() }
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: flags.disabled))
                .disabled(flags.disabled)
        }.padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .task(id: amountToTransfer.value) {
            // re-compute the fees on every tapped digit or backspace
            if let computeFee {
                symLog.log(".task \(amountToTransfer.value)")
                if let result: ComputeFeeResult = await computeFee(amountToTransfer) {
                    symLog.log("computeFee() finished")
                    feeStr = result.feeStr
//                    insufficient = result.insufficient
                    feeAmount = result.feeAmount
                    numCoins = result.numCoins
                } else {
                    symLog.log("computeFee() failed")
                }
            }
        }
    }
}
