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

// Will be called either by the user scanning a pay-template QR code or tapping the provided link,
// both from the shop's website or even from a printed QR code.
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
    @State private var currencyName = EMPTYSTRING
    @State private var amountIsEditable = false
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var shortcutSelected = false
    @State private var buttonSelected1 = false
    @State private var buttonSelected2 = false
    @State private var summaryIsEditable = false
    @State private var summary: String = EMPTYSTRING       // templateParam

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
    func acceptAction(preparePayResult: PreparePayResult) {
        Task { // runs on MainActor
            if let confirmPayResult = try? await model.confirmPayM(preparePayResult.transactionId) {
                //                symLog.log(confirmPayResult as Any)
                if confirmPayResult.type != "done" {
                    controller.playSound(0)
                    // TODO: show error
                }
            }
            dismissTop()
        }
    }

    var body: some View {
        if let templateContract {       // preparePayResult
//            let effective = preparePayResult.amountEffective
//            let baseURL = preparePayResult.contractTerms.exchanges.first?.url
//            let raw = preparePayResult.amountRaw
//            let currency = raw.currencyStr
            let currencyInfo = controller.info(for: currencyName, controller.currencyTicker)
            let amountLabel = minimalistic ? String(localized: "Amount:")
                                           : String(localized: "Amount to pay:")
            let finalDestinationI = LazyView {
                PaymentView(stack: stack.push(),
                              url: url,
                         template: true,
                 amountToTransfer: $amountToTransfer,
                          summary: $summary,
                 amountIsEditable: amountIsEditable,
                summaryIsEditable: summaryIsEditable)
            }  // final destination with amountToTransfer, after user input of amount
            let finalDestinationS = LazyView {
                PaymentView(stack: stack.push(),
                              url: url,
                         template: true,
                 amountToTransfer: $amountShortcut,
                          summary: $summary,
                 amountIsEditable: amountIsEditable,
                summaryIsEditable: summaryIsEditable)
            }  // final destination with amountShortcut, when user tapped a shortcut

            let inputDestination = LazyView {
                SubjectInputV(stack: stack.push(), url: url,
                    amountAvailable: nil,
                   amountToTransfer: $amountToTransfer,
                        amountLabel: amountLabel,
                            summary: $summary,
//                       insufficient: $insufficient,
//                          feeAmount: $feeAmount,
                       feeIsNotZero: true, // TODO: feeIsNotZero()
                       currencyInfo: currencyInfo,
                         targetView: finalDestinationI)
            }   // destination to subject input
            let shortcutDestination = LazyView {
                SubjectInputV(stack: stack.push(), url: url,
                    amountAvailable: nil,
                   amountToTransfer: $amountShortcut,
                        amountLabel: amountLabel,
                            summary: $summary,
//                       insufficient: $insufficient,
//                          feeAmount: $feeAmount,
                       feeIsNotZero: true, // TODO: feeIsNotZero()
                       currencyInfo: currencyInfo,
                         targetView: finalDestinationS)
            }// destination to subject input, when user tapped an amount shortcut
          Group {
            if amountIsEditable {           // template contract amount is not fixed => let the user input an amount first
                let amountInput = AmountInputV(stack: stack.push(), url: url,
                                     amountAvailable: nil,
                                    amountToTransfer: $amountToTransfer,
                                         amountLabel: amountLabel,
                                   summaryIsEditable: summaryIsEditable,
                                             summary: $summary,
//                                        insufficient: $insufficient,
//                                           feeAmount: $feeAmount,
                                      shortcutAction: shortcutAction,
                                        buttonAction: buttonAction1)
                ScrollView {
                    if summaryIsEditable {  // after amount input,
                        amountInput
                            .background(NavigationLink(destination: shortcutDestination, isActive: $shortcutSelected)
                                        { EmptyView() }.frame(width: 0).opacity(0).hidden())
                            .background( NavigationLink(destination: inputDestination, isActive: $buttonSelected1)
                                        { EmptyView() }.frame(width: 0).opacity(0).hidden())

                    } else {
                        amountInput
                            .background(NavigationLink(destination: finalDestinationS, isActive: $shortcutSelected)
                                        { EmptyView() }.frame(width: 0).opacity(0).hidden())
                            .background(NavigationLink(destination: finalDestinationI, isActive: $buttonSelected1)
                                        { EmptyView() }.frame(width: 0).opacity(0).hidden())
                    }
                }
            } else if summaryIsEditable {   // template contract summary is not fixed => let the user input a summary
                ScrollView {
                    inputDestination
                        .background(NavigationLink(destination: finalDestinationI, isActive: $buttonSelected2)
                                    { EmptyView() }.frame(width: 0).opacity(0).hidden()
                        )
                }
            } else {                        // both template contract amount and summary are fixed => directly show the payment
                PaymentView(stack: stack.push(),
                              url: url,
                         template: true,
                 amountToTransfer: $amountToTransfer,
                          summary: $summary,
                 amountIsEditable: amountIsEditable,
                summaryIsEditable: summaryIsEditable)
            }
          }.navigationTitle(navTitle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
          .onAppear() {
              symLog.log("onAppear")
              DebugViewC.shared.setSheetID(SHEET_PAY_TEMPLATE)
          }
        } else {
            LoadingView(scopeInfo: nil, message: url.host)
                .task {
                    if let details = try? await model.checkPayForTemplateM(url.absoluteString) {
                        let contract = details.templateDetails.templateContract     // specifies fixed amount/summary
                        amountIsEditable = contract.amount == nil
                        summaryIsEditable = contract.summary == nil
                        let defaults = details.templateDetails.editableDefaults     // might be nil, or its fields might be nil
                        let prepCurrency = contract.currency ?? defaults?.currency ?? 
                                    (details.supportedCurrencies.count > 0 ? details.supportedCurrencies[0]
                                                                           : String(localized: "UNKNOWN", comment: "merchant didn't specify the currency, use ALL CAPS"))
                        let zeroAmount = Amount(currency: prepCurrency, cent: 0)
                        let prepAmount = contract.amount ?? defaults?.amount        // might be nil
                        let prepSummary = contract.summary ?? defaults?.summary     // might be nil
//                        symLog.log("LoadingView.task preparePayForTemplate")
//                        if let result = await preparePayForTemplate(model: model,
//                                                                      url: url,
//                                                                   amount: amountIsEditable ? prepAmount ?? zeroAmount
//                                                                                            : nil,
//                                                                  summary: summaryIsEditable ? prepSummary ?? " "
//                                                                                             : nil,
//                                                                 announce: announce)
//                        {   symLog.log("preparePayForTemplate finished")
                            amountToTransfer = prepAmount ?? zeroAmount
                            currencyName = prepCurrency
                            summary = prepSummary ?? EMPTYSTRING
                        templateContract = contract
//                            insufficient = result.insufficient
//                            feeAmount = result.feeAmount
//                            feeStr = result.feeStr
//                            preparePayResult = result.ppCheck
//                        } else {
//                            symLog.log("preparePayForTemplateM failed")
//                        }
                    }
                }
        }
    }
}
