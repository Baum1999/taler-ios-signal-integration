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
}

struct AmountInputV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let currencyInfo: CurrencyInfo

    // the scanned URL
    let url: URL?
    let amountAvailable: Amount?                    // TODO: GetMaxPeerPushAmount
    @Binding var amountToTransfer: Amount
    let wireFee: Amount?
    let amountLabel: String
    let summaryIsEditable: Bool                      // if true we call SubjectInputV next
    @Binding var summary: String
//    @Binding var insufficient: Bool
    @Binding var feeAmount: Amount?
    let shortcutAction: ((_ amount: Amount) -> Void)?
    let buttonAction: () -> Void
    let computeFee: ((_ amount: Amount) async -> ComputeFeeResult?)?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var preparePayResult: PreparePayResult? = nil
    @State private var feeStr: String = EMPTYSTRING

    struct Flags {
        let insufficient: Bool
        let disabled: Bool
    }

    func checkAvailable(amount: Amount) -> Flags {
        if let amountAvailable {
            do {
                let insufficient = try amount > amountAvailable
                let disabled = insufficient || amount.isZero
                return Flags(insufficient: insufficient, disabled: disabled)
            } catch {
                // TODO: error Amounts don't match
            }
        }
        return Flags(insufficient: false, disabled: amount.isZero)
    }

    var body: some View {
        let currency = amountToTransfer.currencyStr
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        let insufficientLabel = String(localized: "You don't have enough \(currency).")
        let available = amountAvailable?.formatted(currencyInfo, isNegative: false) ?? nil
        let flags = checkAvailable(amount: amountToTransfer)
        VStack(alignment: .trailing) {
            if summary.count > 0 {
                Text(summary)
                    .talerFont(.body)
                    .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
                    .padding(4)
            }
            if let available {
                Text("Available:\t\(available)")
                    .talerFont(.title3)
                    .padding(.bottom, 2)
//                  .accessibility(sortPriority: 3)
            } // available
            CurrencyInputView(currencyInfo: currencyInfo,
                                    amount: $amountToTransfer,
                                 available: amountAvailable,
                                     title: amountLabel,
                            shortcutAction: shortcutAction)
//                .accessibility(sortPriority: 2)

            let color = flags.insufficient || !(feeAmount?.isZero ?? true) ? .red
                      : WalletColors().secondary(colorScheme, colorSchemeContrast)
            Text(flags.insufficient ? insufficientLabel : feeLabel(feeStr))
                .talerFont(.body)
                .foregroundColor(color)
                .padding(4)
                .accessibility(sortPriority: 1)
            Button("Next") { buttonAction() }
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: flags.disabled))
                .disabled(flags.disabled)
        }.padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear() {
//          symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_PAY_TEMPL_AMOUNT)
        }
        .task(id: amountToTransfer.value) {
            // re-compute the fees on every tapped digit or backspace
            if let computeFee {
                symLog.log(".task computeFee")
                if let result: ComputeFeeResult = await computeFee(amountToTransfer) {
                    symLog.log("computeFee() finished")
                    feeStr = result.feeStr
//                    insufficient = result.insufficient
//                    feeAmount = result.feeAmount
                } else {
                    symLog.log("computeFee() failed")
                }
            }
        }
    }
}
