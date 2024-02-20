/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
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
    let amountLabel: String
    let wantsSummary: Bool                      // if true we call SubjectInputV next
    @Binding var summary: String
    @Binding var insufficient: Bool
    @Binding var feeAmount: Amount?
    let shortcutAction: ((_ amount: Amount) -> Void)?
    let buttonAction: () -> Void

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var preparePayResult: PreparePayResult? = nil
    @State private var feeStr: String = EMPTYSTRING

    var feeLabel: String { feeStr.count > 0 ? String(localized: "+ \(feeStr) fee") : EMPTYSTRING }

    func preparePayForTemplate() async {
        if let url {
            do {
                let ppCheck = try await model.preparePayForTemplateM(url.absoluteString, amount: amountToTransfer, summary: summary)
                let amount = ppCheck.amountRaw
                let currency = amount.currencyStr
                let currencyInfo = controller.info(for: currency, controller.currencyTicker)
                insufficient = ppCheck.status == .insufficientBalance
                feeAmount = templateFee(ppCheck: ppCheck)
                if let feeAmount {
                    feeStr = feeAmount.string(currencyInfo)
                } else { feeStr = EMPTYSTRING }
                let amountVoiceOver = amount.string(currencyInfo)
                announce(this: "\(amountVoiceOver), \(feeLabel)")
                preparePayResult = ppCheck
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }

    var body: some View {
        let currency = amountToTransfer.currencyStr
        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
        let insufficientLabel = String(localized: "You don't have enough \(currency).")
        let available = amountAvailable?.string(currencyInfo) ?? nil
        let disabled = insufficient || amountToTransfer.isZero
        VStack(alignment: .trailing) {
            if let available {
                Text("Available:\t\(available)")
                    .talerFont(.title3)
                    .padding(.bottom, 2)
                //                .accessibility(sortPriority: 3)
            }
            CurrencyInputView(amount: $amountToTransfer,
                           available: amountAvailable,
                               title: amountLabel,
                      shortcutAction: shortcutAction)
//                .accessibility(sortPriority: 2)
            Text(insufficient ? insufficientLabel
                              : feeLabel)
                .talerFont(.body)
                .foregroundColor(insufficient ? .red
                : (feeAmount?.isZero ?? true) ? WalletColors().secondary(colorScheme, colorSchemeContrast)
                                              : .red)
//                .accessibility(sortPriority: 1)
                .padding(4)
            Group {
                if let url {
                    let destination = LazyView {
                        PaymentView(stack: stack.push(),
                                      url: url,
                                 template: true,
                         amountToTransfer: $amountToTransfer,
                                  summary: $summary)
                    }
                    NavigationLink(destination: destination) {
                        Text("Next")
                    }
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .disabled(disabled)
                } else {
                    Button("Next") {
                        buttonAction()
                    }
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .disabled(disabled)
                }
            }
//                .accessibility(sortPriority: 0)
                .task(id: amountToTransfer.value) {
                    symLog.log(".task")
                    await preparePayForTemplate()
                }
        }.padding(.horizontal)
            .onAppear() {
                //            symLog.log("onAppear")
                DebugViewC.shared.setSheetID(SHEET_PAY_TEMPL_AMOUNT)
            }
    }
}
