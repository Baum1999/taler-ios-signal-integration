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

struct SubjectInputV<TargetView: View>: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    // the scanned URL
    let url: URL?
    let amountAvailable: Amount?            // TODO: getMaxDepositAmountM, getMaxPeerPushDebitAmountM
    @Binding var amountToTransfer: Amount
    let amountLabel: String
    @Binding var summary: String
//    @Binding var insufficient: Bool
//    @Binding var feeAmount: Amount?
    let feeIsNotZero: Bool?             // nil = no fees at all, false = no fee for this tx

    var targetView: TargetView

//    let destination: Destination

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @AppStorage("minimalistic") var minimalistic: Bool = false

    let navTitle = String(localized: "Custom Summary", comment:"pay merchant")

    @FocusState private var isFocused: Bool

    var body: some View {
        let currency = amountToTransfer.currencyStr
//        let feeStr = feeAmount?.string(currencyInfo) ?? EMPTYSTRING
//        let insufficientLabel = String(localized: "You don't have enough \(currency).")
//        let feeLabel = insufficient ? insufficientLabel
//                                    : feeLabel(feeStr)
//        let available = amountAvailable?.formatted(scope, isNegative: false) ?? nil
//        let disabled = insufficient || summary.count == 0
        let disabled = summary.count == 0
        ScrollView { VStack(alignment: .leading) {
//            if let available {
//                Text("Available:\t\(available)")
//                    .talerFont(.title3)
//                    .padding(.bottom, 2)
////                    .accessibility(sortPriority: 3)
//            }

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
//                  .lineLimit(2...5)   // lineLimit' is only available in iOS 16.0 or newer
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
//            HStack {
//                Text(amountToTransfer.formatted(currencyInfo, isNegative: false))
//                // TODO: hasFees?
////                Text(feeLabel)
//            }
//                .talerFont(.body)
////                .foregroundColor(insufficient ? .red : WalletColors().secondary(colorScheme, colorSchemeContrast))
//                .foregroundColor(WalletColors().secondary(colorScheme, colorSchemeContrast))
////                .accessibility(sortPriority: 1)
//                .padding(4)
//            if insufficient {
//                Text(insufficientLabel)
//                    .talerFont(.body)
//                    .foregroundColor(WalletColors().attention)
//                    .padding(4)
//            }

            NavigationLink("Next", destination: targetView)
                .buttonStyle(TalerButtonStyle(type: .prominent, disabled: disabled))
                .disabled(disabled)
//                .accessibility(sortPriority: 0)
        }.padding(.horizontal) } // ScrollVStack
        .navigationTitle(navTitle)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
        .onAppear() {
//            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_PAY_TEMPL_SUBJECT)
        }
    }
}
