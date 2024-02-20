/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct SubjectInputV<TargetView: View>: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    // the scanned URL
    let url: URL?
    let amountAvailable: Amount?                    // TODO: GetMaxPeerPushAmount
    @Binding var amountToTransfer: Amount
    let amountLabel: String
    @Binding var summary: String
    @Binding var insufficient: Bool
    @Binding var feeAmount: Amount?
    let feeIsNotZero: Bool?             // nil = no fees at all, false = no fee for this tx
    let currencyInfo: CurrencyInfo

    var targetView: TargetView

//    let destination: Destination

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    @State private var preparePayResult: PreparePayResult? = nil
    @State private var feeStr: String = EMPTYSTRING
    @FocusState private var isFocused: Bool

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
        let disabled = insufficient || summary.count == 0
        VStack(alignment: .leading) {
            if let available {
                Text("Available:\t\(available)")
                    .talerFont(.title3)
                    .padding(.bottom, 2)
//                    .accessibility(sortPriority: 3)
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
                    .focused($isFocused)
                    .lineLimit(2...)
            } else {
                TextField("Subject", text: $summary)
                    .focused($isFocused)
                //                      .lineLimit(2...5)   // lineLimit' is only available in iOS 16.0 or newer
            } } // Group for iOS16+ & iOS15
            .talerFont(.title2)
            .foregroundColor(WalletColors().fieldForeground)     // text color
            .background(WalletColors().fieldBackground)
            .textFieldStyle(.roundedBorder)
            .onAppear {
                symLog.log("dispatching kbd...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    isFocused = true        // make first responder - raise keybord
                    symLog.log("...kbd isFocused")
                }
            }

            let subLabel = insufficient ? insufficientLabel
                                        : feeLabel
            Text(subLabel)
                .talerFont(.body)
                .foregroundColor(insufficient ? .red
                                 : (feeAmount?.isZero ?? true) ? WalletColors().secondary(colorScheme, colorSchemeContrast)
                                 : .red)
            //                    .accessibility(sortPriority: 1)
                .padding(4)

            NavigationLink("Next", destination: targetView)
                .buttonStyle(TalerButtonStyle(type: .prominent))
                .disabled(disabled)
//                .accessibility(sortPriority: 0)
        }.padding(.horizontal)
        .onAppear() {
//            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_PAY_TEMPL_SUBJECT)
        }
    }
}
