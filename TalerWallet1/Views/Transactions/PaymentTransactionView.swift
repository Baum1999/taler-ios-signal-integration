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

    func summary(_ terms: MerchantContractTerms) -> String {
        if let i18nDict = terms.summaryI18n {
            if !i18nDict.isEmpty {
                for code in Locale.preferredLanguageCodes {
                    if let descI18n = i18nDict[code] {
                        return descI18n
                    }
                }
            }
        }
        return terms.summary
    }

    func logo(_ logoBase64: String) -> Image? {
        if let image = Image(imageBase64: logoBase64) {
            return image
        }
        return nil
    }
    var body: some View {
        if let terms {
            Section {
                Text(summary(terms))
                    .talerFont(.title3)
            } header: {
                HStack {
                    Spacer()
                    VStack(alignment: .center) {
                        if let imageBase64 = terms.merchant.logo {
                            if let image = logo(imageBase64) {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 60)
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
                    }.foregroundStyle(Color(.primary))
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
    @Binding var payNow: Bool
    @Binding var selectedChoice: Int?

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel

    func summary(_ info: OrderShortInfo?) -> String? {
        if let i18nDict = info?.summary_i18n {
            if !i18nDict.isEmpty {
                for code in Locale.preferredLanguageCodes {
                    if let i18n = i18nDict[code] {
                        return i18n
                    }
                }
            }
        }
        if let summary = info?.summary {
            return summary
        }
        return String(localized: "No summary", comment: "OrderShortInfo.summary")
    }

    func selectIndex(_ index: Int?, of choices: [ChoiceTriple]) -> Int? {
        let index1 = index ?? 0
        let select = index1 < choices.count ? index1 : 0
        let choice = choices[select]
        let selectionDetail = choice.0
        if selectionDetail.status == .paymentPossible {
            selectedChoice = select
            effective = selectionDetail.amountEffective
            return select
        }
        return nil
    }

    func automaticOrDefault(_ automaticIndex: Int?,_ defaultChoiceIndex: Int?, of choices: [ChoiceTriple]) {
        if let automaticIndex {
            // Pay Automatically - usually with a subscription token
            if let selectedAutomatic = selectIndex(automaticIndex, of: choices) {
                if selectedAutomatic == automaticIndex {
                    // TODO: check if automatic choice does NOT have an amount
                    // we definitely don't want to pay MONEY automatically, only tokens
                    payNow = true
                    return
                } else if let defaultChoiceIndex {
                    if selectedAutomatic == defaultChoiceIndex { return }
                    // else fall thru and select defaultChoiceIndex
                } else {
                    return      // there is no default - keep selectedAutomatic
                }
            }
        }
        let _ = selectIndex(defaultChoiceIndex, of: choices)
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()
#endif
        let details = paymentTransaction.details
        if common.isDialog {        // show payment confirmation dialog
            MerchantHeader(terms: details.contractTerms)

            let choicesTuple = controller.choicesTuple
            if let txId = choicesTuple.0, let choicesForPayment = choicesTuple.1 {
                if let (choices, showHeader) = choicesForPayment.choiceTriple() {
                    let hasAutomatic = choicesForPayment.automaticExecution ?? false
                    let automaticIndex = hasAutomatic ? choicesForPayment.automaticExecutableIndex : nil
                    ChoicesView(stack: stack.push(),
                         choiceTriple: choices,
                           showHeader: showHeader,
                       automaticIndex: automaticIndex,
                       selectedChoice: $selectedChoice)
                    .task {
                        automaticOrDefault(automaticIndex, choicesForPayment.defaultChoiceIndex, of: choices)
                    }
                    .onChange(of: selectedChoice) { newValue in
                        if let newValue, newValue < choices.count {
                            let newChoice = choices[newValue]
                            effective = newChoice.0.amountEffective
                            scope = newChoice.0.scopeInfo
                        } else {
                            effective = nil
                            scope = nil
                        }
                    }

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
                                   summary: summary(details.info),
                                  products: details.info?.products ?? [],
                            balanceDetails: selectionDetail.balanceDetails)
                    }
                }
            }
        } else { // show finished payment
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
                            summary: details.info?.summary ?? EMPTYSTRING)
        } // show finished payment
    } // body
} // PaymentTransactionView
