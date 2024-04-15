/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

func templateFee(ppCheck: PreparePayResult?) -> Amount? {
    do {
        if let ppCheck {
            // Outgoing: fee = effective - raw
            if let effective = ppCheck.amountEffective {
                let fee = try effective - ppCheck.amountRaw
                return fee
            }
        }
    } catch {}
    return nil
}

// Will be called either by the user scanning a QR code or tapping the provided link,
// both from the shop's website. We show the payment details
struct PayTemplateV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    // the scanned URL
    let url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    let navTitle = String(localized: "Customize Order", comment:"pay merchant")

    @State private var insufficient = false
    @State private var preparePayResult: PreparePayResult? = nil
    @State private var currencyName: String? = nil
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
    @State private var amountShortcut = Amount.zero(currency: EMPTYSTRING)      // Update currency when used
    @State private var shortcutSelected = false
    @State private var buttonSelected1 = false
    @State private var buttonSelected2 = false
    @State private var summary: String = EMPTYSTRING       // templateParam
    @State private var wantsSummary: Bool = false
    @State private var feeAmount: Amount? = nil
    @State private var feeStr: String = EMPTYSTRING

    var feeLabel: String { feeStr.count > 0 ? String(localized: "+ \(feeStr) fee") : EMPTYSTRING }

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

    func queryURL() -> Bool {
        if let queryParameters = url.queryParameters {
            if let amountStr = queryParameters["amount"] {
                currencyName = amountStr
                amountToTransfer = Amount.zero(currency: amountStr)
            }
            if let summaryStr = queryParameters["summary"] {
                summary = summaryStr
                wantsSummary = true
            }
            return true
        }
        return false
    }

    func preparePayForTemplate() async {
        if let ppCheck = try? await model.preparePayForTemplateM(url.absoluteString, amount: amountToTransfer, summary: summary) {
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
        }
    }

    var body: some View {
        if let preparePayResult {
            let effective = preparePayResult.amountEffective
            let baseURL = preparePayResult.contractTerms.exchanges.first?.url
            let raw = preparePayResult.amountRaw
            let currency = raw.currencyStr
            let currencyInfo = controller.info(for: currency, controller.currencyTicker)
            let amountLabel = minimalistic ? String(localized: "Amount:")
                                           : String(localized: "Amount to pay:")
            let finalDestinationI = LazyView {
                PaymentView(stack: stack.push(),
                              url: url,
                         template: true,
                 amountToTransfer: $amountToTransfer,
                          summary: $summary)
            }
            let inputDestination = LazyView {
                SubjectInputV(stack: stack.push(), url: url,
                    amountAvailable: nil,
                   amountToTransfer: $amountToTransfer,
                        amountLabel: amountLabel,
                            summary: $summary,
                       insufficient: $insufficient,
                          feeAmount: $feeAmount,
                       feeIsNotZero: true, // feeIsNotZero(),
                       currencyInfo: currencyInfo,
                         targetView: finalDestinationI)
            }
            let finalDestinationS = LazyView {
                PaymentView(stack: stack.push(),
                              url: url,
                         template: true,
                 amountToTransfer: $amountShortcut,
                          summary: $summary)
            }
            let shortcutDestination = LazyView {
                SubjectInputV(stack: stack.push(), url: url,
                    amountAvailable: nil,
                   amountToTransfer: $amountShortcut,
                        amountLabel: amountLabel,
                            summary: $summary,
                       insufficient: $insufficient,
                          feeAmount: $feeAmount,
                       feeIsNotZero: true, // feeIsNotZero(),
                       currencyInfo: currencyInfo,
                         targetView: finalDestinationS)
            }
          Group {
            if let currencyName {    // template included a currency name => let the user input an amount
                let amountInput = AmountInputV(stack: stack.push(), url: url,
                                     amountAvailable: nil,
                                    amountToTransfer: $amountToTransfer,
                                         amountLabel: amountLabel,
                                        wantsSummary: wantsSummary,
                                             summary: $summary,
                                        insufficient: $insufficient,
                                           feeAmount: $feeAmount,
                                      shortcutAction: shortcutAction,
                                        buttonAction: buttonAction1)
                ScrollView {
                    if wantsSummary {
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
                } // ScrollVStack
            } else if wantsSummary { // check summary
                ScrollView {
                    inputDestination
                        .background(NavigationLink(destination: finalDestinationI, isActive: $buttonSelected2)
                                    { EmptyView() }.frame(width: 0).opacity(0).hidden()
                        )
                }
            } else {
                PaymentView(stack: stack.push(),
                              url: url,
                         template: true,
                 amountToTransfer: $amountToTransfer,
                          summary: $summary)
            }
          }.onAppear() {
              symLog.log("onAppear")
              DebugViewC.shared.setSheetID(SHEET_PAY_TEMPLATE)
          }.navigationTitle(navTitle)
        } else {
            LoadingView(scopeInfo: nil, message: url.host)
                .task {
                    symLog.log("LoadingView.task preparePayForTemplate")
                    let hasParams = queryURL()
                    await preparePayForTemplate()
                    symLog.log("preparePayForTemplate finished")
                }
        }
    }
}
