/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called either by the user scanning a <pay-template> QR code or tapping the provided link,
// both from the shop's website - or even from a printed QR code.
// We check whether amount and/or summary is editable, and finally go to PaymentView
struct PayTemplateV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    // the scanned URL
    let url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let navTitle = String(localized: "Custom Amount", comment:"pay merchant")

//    @State private var insufficient = false
//    @State private var preparePayResult: PreparePayResult? = nil
    @State private var templateContract: TemplateContractDetails? = nil
    @State private var amountIsEditable = false
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var amountAvailable = Amount.zero(currency: EMPTYSTRING)     // TODO: set correct available amount (like in SendAmountV)
    @State private var shortcutSelected = false
    @State private var buttonSelected1 = false
    @State private var buttonSelected2 = false
    @State private var summaryIsEditable = false
    @State private var summary: String = EMPTYSTRING       // templateParam
    @State private var scope: ScopeInfo? = nil

//    @State private var feeAmount: Amount? = nil
//    @State private var feeStr: String = EMPTYSTRING

    private func shortcutAction(_ shortcut: Amount) {
        amountShortcut = shortcut
        shortcutSelected = true
    }
    private func buttonAction1() {
        buttonSelected1 = true
    }
    private func buttonAction2() {
        buttonSelected2 = true
    }

    @MainActor
    func acceptAction(preparePayResult: PreparePayResult) {
        Task { // runs on MainActor
            if let confirmPayResult = try? await model.confirmPay(preparePayResult.transactionId) {
//                symLog.log(confirmPayResult as Any)
                if confirmPayResult.type == "done" {
                    dismissTop(stack.push())
                } else if confirmPayResult.type == "error" {
                    controller.playSound(0)
                    // TODO: show error
                }
            }
        }
    }

    private func computeFeePayTemplate(_ amount: Amount) async -> ComputeFeeResult? {
//        if let result = await preparePayForTemplate(model: model,
//                                                      url: url,
//                                                   amount: amountToTransfer,
//                                                  summary: summaryIsEditable ? summary ?? SPACE
//                                                                             : nil,
//                                                 announce: announce)
//        {
//            preparePayResult = result.ppCheck
//        }
        return nil
    }

    @MainActor
    private func viewDidLoad() async {
        if let response = try? await model.checkPayForTemplate(url.absoluteString) {
            let details = response.templateDetails
            let defaults = details.editableDefaults     // might be nil, or its fields might be nil
                                                        // TODO: let the user choose a currency from supportedCurrencies[]
            let supportedCurrencies = response.supportedCurrencies

            /// checkPayForTemplate does not provide fees (yet)
            let contract = details.templateContract     // specifies fixed amount/summary
            if let amount = contract.amount {
                controller.updateAmount(amount, forSaved: url)
            }
            amountIsEditable = contract.amount == nil
            summaryIsEditable = contract.summary == nil

            let prepCurrency = contract.currency ?? defaults?.currency ??
                             (supportedCurrencies.count > 0 ? supportedCurrencies[0]
                                                            : UNKNOWN)
            let zeroAmount = Amount(currency: prepCurrency, cent: 0)
            let prepAmount = contract.amount ?? defaults?.amount        // might be nil
            let prepSummary = contract.summary ?? defaults?.summary     // might be nil
//          symLog.log("LoadingView.task preparePayForTemplate")
            /// preparePayForTemplate will make a network call to the merchant and create a TX
            ///  -> we only want to do this after the user entered amount and subject - but before confirmation of course
//          if let result = await preparePayForTemplate(model: model,
//                                                        url: url,
//                                                     amount: amountIsEditable ? prepAmount ?? zeroAmount
//                                                                              : nil,
//                                                    summary: summaryIsEditable ? prepSummary ?? SPACE
//                                                                               : nil,
//                                                   announce: announce)
//          {   symLog.log("preparePayForTemplate finished")
                amountToTransfer = prepAmount ?? zeroAmount
                summary = prepSummary ?? EMPTYSTRING
                templateContract = contract
//              insufficient = result.insufficient
//              feeAmount = result.feeAmount
//              feeStr = result.feeStr
//              preparePayResult = result.ppCheck
//          } else {
//              symLog.log("preparePayForTemplateM failed")
//          }
        }

    }
    var body: some View {
        if let templateContract {       // preparePayResult
//            let currency = templateContract.currency ?? templateContract.amount?.currencyStr ?? UNKNOWN
            let a11yLabel = String(localized: "Amount to pay:", comment: "a11y, no abbreviations")
            let amountLabel = minimalistic ? String(localized: "Amount:")
                                           : a11yLabel
            // final destination with amountToTransfer, after user input of amount
            let finalDestinationI = PaymentView(stack: stack.push(),
                                                  url: url,
                                             template: true,
                                     amountToTransfer: $amountToTransfer,
                                              summary: $summary,
                                     amountIsEditable: amountIsEditable,
                                    summaryIsEditable: summaryIsEditable)

            // final destination with amountShortcut, when user tapped a shortcut
            let finalDestinationS = PaymentView(stack: stack.push(),
                                                  url: url,
                                             template: true,
                                     amountToTransfer: $amountShortcut,
                                              summary: $summary,
                                     amountIsEditable: amountIsEditable,
                                    summaryIsEditable: summaryIsEditable)

            // destination to subject input
            let inputDestination = SubjectInputV(stack: stack.push(),
                                                   url: url,
                                       amountAvailable: nil,
                                      amountToTransfer: $amountToTransfer,
                                           amountLabel: amountLabel,
                                               summary: $summary,
//                                        insufficient: $insufficient,
//                                           feeAmount: $feeAmount,
                                          feeIsNotZero: true, // TODO: feeIsNotZero()
                                            targetView: finalDestinationI)

            // destination to subject input, when user tapped an amount shortcut
            let shortcutDestination = SubjectInputV(stack: stack.push(),
                                                      url: url,
                                          amountAvailable: nil,
                                         amountToTransfer: $amountShortcut,
                                              amountLabel: amountLabel,
                                                  summary: $summary,
//                                           insufficient: $insufficient,
//                                              feeAmount: $feeAmount,
                                             feeIsNotZero: true, // TODO: feeIsNotZero()
                                               targetView: finalDestinationS)
          Group {
            if amountIsEditable {           // template contract amount is not fixed => let the user input an amount first
                let amountInput = AmountInputV(stack: stack.push(),
                                               scope: scope,
                                     amountAvailable: $amountAvailable,
                                         amountLabel: amountLabel,
                                           a11yLabel: a11yLabel,
                                    amountToTransfer: $amountToTransfer,
                                      amountLastUsed: amountLastUsed,
                                             wireFee: nil,
                                             summary: $summary,
                                      shortcutAction: shortcutAction,
                                        buttonAction: buttonAction1,
                                          isIncoming: false,
                                          computeFee: computeFeePayTemplate)
                ScrollView {
                    if summaryIsEditable {  // after amount input,
                        amountInput
                            .background( NavLink($shortcutSelected) { shortcutDestination } )
                            .background( NavLink($buttonSelected1) { inputDestination} )

                    } else {
                        amountInput
                            .background( NavLink($shortcutSelected) { finalDestinationS } )
                            .background( NavLink($buttonSelected1) { finalDestinationI } )
                    }
                } // amountInput
            } else if summaryIsEditable {   // template contract summary is not fixed => let the user input a summary
                ScrollView {
                    inputDestination
                        .background( NavLink($buttonSelected2) { finalDestinationI } )
                } // inputDestination
            } else {    // both template contract amount and summary are fixed => directly show the payment
                // Attention: contains a List, thus mustn't be included in a ScrollView
                PaymentView(stack: stack.push(),
                              url: url,
                         template: true,
                 amountToTransfer: $amountToTransfer,
                          summary: $summary,
                 amountIsEditable: amountIsEditable,
                summaryIsEditable: summaryIsEditable)
            }
          } .navigationTitle(navTitle)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
            .onAppear() {
                symLog.log("onAppear")
                DebugViewC.shared.setSheetID(SHEET_PAY_TEMPLATE)
            }
        } else {
            LoadingView(stack: stack.push(), scopeInfo: nil, message: url.host)
                .task { await viewDidLoad() }
        }
    }
}
