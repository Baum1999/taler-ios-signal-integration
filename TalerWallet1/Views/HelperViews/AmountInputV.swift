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

struct AmountInputV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    // the scanned URL
    let url: URL?
    let amountAvailable: Amount?                    // TODO: GetMaxPeerPushAmount
    @Binding var amountToTransfer: Amount
    let wireFee: Amount?
    let amountLabel: String
    let summaryIsEditable: Bool                      // if true we call SubjectInputV next
    @Binding var summary: String
//    @Binding var insufficient: Bool
//    @Binding var feeAmount: Amount?
    let shortcutAction: ((_ amount: Amount) -> Void)?
    let buttonAction: () -> Void

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
        let available = amountAvailable?.formatted(currencyInfo) ?? nil
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
            }
            CurrencyInputView(amount: $amountToTransfer,
                           available: amountAvailable,
                               title: amountLabel,
                      shortcutAction: shortcutAction)
//                .accessibility(sortPriority: 2)
            if flags.insufficient {
                Text(insufficientLabel)
                    .talerFont(.body)
                    .foregroundColor(.red)
                    .padding(4)
//            } else {
//                Text(feeLabel(feeStr))
//                    .talerFont(.body)
//                    .foregroundColor((feeAmount?.isZero ?? true) ? WalletColors().secondary(colorScheme, colorSchemeContrast)
//                                     : .red)
//                    .padding(4)
//                  .accessibility(sortPriority: 1)
            }
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
//        .task(id: amountToTransfer.value) {
//            if let url {
//                symLog.log(".task preparePayForTemplate")
//                if let result = await preparePayForTemplate(model: model,
//                                                              url: url,
//                                                           amount: amountToTransfer,
//                                                          summary: summaryIsEditable ? summary ?? " "
//                                                                                     : nil,
//                                                         announce: announce)
//                {   symLog.log("preparePayForTemplate finished")
//                    insufficient = result.insufficient
//                    feeAmount = result.feeAmount
//                    feeStr = result.feeStr
//                    preparePayResult = result.ppCheck
//                } else {
//                    symLog.log("preparePayForTemplateM failed")
//                }
//            }
//        }
    }
}
