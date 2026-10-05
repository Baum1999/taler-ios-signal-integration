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

// MARK: -
struct MerchantHeader: View {
    let terms: MerchantContractTerms?

    @State private var image: Image? = nil

    var body: some View {
        if let terms {
            Section {
                Text(terms.locSummary)
                    .talerFont(.title3)
            } header: {
                HStack {
                    Spacer()
                    VStack(alignment: .center) {
                        if terms.merchant.logo != nil {
                            if let image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 50)
                            }
                        } else {
#if TALER_NIGHTLY
                            let imageName = if #available(iOS 17.0, *) { MERCHANT17 } else { MERCHANT14 }
                            Image(systemName: imageName)
                                .resizable()
                                .frame(width: 44, height: 44)
#endif
                        }
                        let merchant = terms.merchant.name
                        Text(merchant)
                            .talerFont(.title3)
                    }   .foregroundStyle(Color.primary)
                        .task {
                            if let imageBase64 = terms.merchant.logo {
                                image = Image(imageBase64: imageBase64)
                            }
                        }
                    Spacer()
                }
            }
        }
    }
}
// MARK: -
struct PaymentTransactionView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let common: TransactionCommon
    let paymentTransaction: PaymentTransaction
    @Binding var scope: ScopeInfo?
    @Binding var effective: Amount?
    @Binding var possible: Bool?
    @Binding var payNow: Bool
    @Binding var selectedChoice: Int?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    func selectIndex(_ index: Int?, of choices: [ChoiceTriple]) -> Int? {
        let index1 = index ?? 0
        let select = index1 < choices.count ? index1 : 0
        let choice = choices[select]
        let selectionDetail = choice.0
        if selectionDetail.status == .paymentPossible {
            selectedChoice = select
            effective = selectionDetail.amountEffective
            possible = true
            return select
        } else {
            possible = false
        }
        return nil
    }

    func automaticOrDefault(_ automaticIndex: Int?,_ defaultChoiceIndex: Int?, of choices: [ChoiceTriple]) {
        if let automaticIndex {
            // Pay Automatically - usually with a subscription token
            if let selectedAutomatic = selectIndex(automaticIndex, of: choices) {
                if selectedAutomatic == automaticIndex {
                    // check if automatic choice does NOT have an amount
                    let choiceTriple = choices[selectedAutomatic]
                    let selectionDetail = choiceTriple.0
                    if selectionDetail.status == .paymentPossible {
                        // we currently don't want to pay MONEY automatically, only tokens
                        // TODO: make the maximum value a user default
                        if selectionDetail.amountRaw.isZero {
                            payNow = true
                        }
                    }
                    return
                } else if let defaultChoiceIndex {
                    if selectedAutomatic == defaultChoiceIndex { return }
                        // else fall thru and select defaultChoiceIndex
                } else {      // there is no default - keep selectedAutomatic
                    return
                }
            }
        }
        _ = selectIndex(defaultChoiceIndex, of: choices)
    }

    var isNotClaiming: Bool {
        !common.isClaiming
    }
    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()
#endif
        let details = paymentTransaction.details
        if common.isDialog {        // show payment confirmation dialog
            let state = common.txState
            MerchantHeader(terms: details.contractTerms)
                .task(id: state.hashValue) {
                    let choicesTuple = controller.choicesTuple
                    let choicesForPayment = choicesTuple.1
                    if choicesTuple.0 != common.transactionId || choicesForPayment == nil {
                        symLog.log("❗️❗️ task: \(state)")
                        await controller.loadChoicesForPayment(stack.push(),
                                                          txId: common.transactionId)
                    } else {
                        symLog.log("❗️❗️ choicesForPayment exists, no need for task: \(state)")
                    }
                }

            let choicesTuple = controller.choicesTuple
            if let txId = choicesTuple.0, let choicesForPayment = choicesTuple.1 {
                let terms = choicesForPayment.contractTerms
                if txId == common.transactionId {
                    if let (choices, showHeader) = choicesForPayment.choiceTriple() {
                        let hasAutomatic = choicesForPayment.automaticExecution ?? false
                        let automaticIndex = hasAutomatic ? choicesForPayment.automaticExecutableIndex : nil
                        ChoicesView(stack: stack.push(),
                             choiceTriple: choices,
                               showHeader: showHeader,
                           automaticIndex: automaticIndex,
                           selectedChoice: $selectedChoice)
                        .task {
                            automaticOrDefault(automaticIndex, choicesForPayment.defaultChoiceIndex, of:    choices)
                        }
                        .onChange(of: selectedChoice) { newValue in
                            if let newValue, newValue < choices.count {
                                let newChoice = choices[newValue]
                                effective = newChoice.0.amountEffective
                                possible = newChoice.0.status == .paymentPossible
                                scope = newChoice.0.scopeInfo
                            } else {
                                effective = nil
                                possible = nil
                                scope = nil
                            }
                        }

                        let summary = details.info?.locSummary ??
                            String(localized: "No summary", comment: "OrderShortInfo.summary")
                        if let selectedChoice {
                            let choice = choices[selectedChoice]
                            let selectionDetail: ChoiceSelectionDetail = choice.0
    //                        let contractChoice: ContractChoice = choice.1
                            PaymentView2(stack: stack.push(),           // TODO: details.info.merchant.name
                                          paid: false,
                                           raw: selectionDetail.amountRaw,
                                     effective: effective,
                                    firstScope: scope,
                                       baseURL: nil,
                                       summary: summary,
                                      products: terms.products ?? [],
                                balanceDetails: selectionDetail.balanceDetails)
                        } else if let choice = choices.first {
                            let selectionDetail: ChoiceSelectionDetail = choice.0

                            PaymentView2(stack: stack.push(),           // TODO: details.info.merchant.name
                                          paid: false,
                                           raw: selectionDetail.amountRaw,
                                     effective: nil,
                                    firstScope: scope,
                                       baseURL: nil,
                                       summary: summary,
                                      products: terms.products ?? [],
                                balanceDetails: selectionDetail.balanceDetails)
                        }
                    } else { // should never happen...
                        // TODO: show some error
                    }
                } else {    // cached data outdated
                    // TODO: purge and reload
                }
            }
        } else if isNotClaiming { // show finished payment
            TransactionPayDetailV(stack: stack.push(),
                              paymentTx: paymentTransaction)    // TODO: details.info.merchant.name
            ThreeAmountsSheet(stack: stack.push(),
                              scope: scope,
                             common: common,
                          topAbbrev: String(localized: "Price:", comment: "mini"),
                           topTitle: String(localized: "Price (net):"),
                            baseURL: nil,               // TODO: baseURL
                             noFees: nil,               // TODO: noFees
                      feeIsNegative: false,
                              large: true,
                            summary: details.info?.locSummary ?? EMPTYSTRING)
        } // show finished payment
    } // body
} // PaymentTransactionView
