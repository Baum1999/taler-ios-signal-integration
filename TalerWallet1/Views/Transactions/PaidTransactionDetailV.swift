/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Overview when there's more than 1 currency/exchange
 *
 * @author Marc Stibane
 */
import SwiftUI

struct PaidTransactionDetailV: View {
    let stack: CallStack
    let paymentTx: PaymentTransaction

#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    var body: some View {
        let common = paymentTx.common
        let details = paymentTx.details
        let terms = details.contractTerms
        let info = details.info
        Section {
            if let posConfirmation = details.posConfirmation {
                Text("Confirmation:", comment: "purchase may have a pos validation / confirmation")
                    .talerFont(.title3)
                    .listRowSeparator(.hidden)
                let totp = Text(posConfirmation)
                    .talerFont(.title1)
                let posConfirmationViaNfc = details.posConfirmationViaNfc
                let isPaying = common.isDialog   // We are ALWAYS already finished with the tx
                if #available(iOS 17.7, *) {
                    BorderWithNFC(totpString: posConfirmation, nfcHint: true,
                                automaticNfc: isPaying ? posConfirmationViaNfc : false,
                                        size: 250, scanHints: nil
                    ) { totp }
                } else {
                    totp
                }
            }
            if let info {
//              Text(info.merchant.name)        TODO: show name & logo here?
                Text("Order-ID:")
                    .talerFont(.title3)
                    .listRowSeparator(.hidden)
                Text(info.orderId)
                    .talerFont(.body)

                if let fulfillmentUrl = info.fulfillmentUrl, common.isDone {
                    // per api-common.rst's WebURL definition, fulfillment_url must be http(s) -
                    // reject any other scheme (tel:, sms:, a third-party app's custom scheme, ...)
                    if let destination = URL(string: fulfillmentUrl),
                       let scheme = destination.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                        let buttonTitle = info.fulfillmentMessage ?? String(localized: "Open merchant website")
                        Link(buttonTitle, destination: destination)
                            .buttonStyle(TalerButtonStyle(type: .prominent))
                            .accessibilityHint(String(localized: "Will go to the merchant website.", comment: "a11y"))
                    }
                } else if let fulfillmentMessage = info.fulfillmentMessage {
                    Text(fulfillmentMessage)
                        .talerFont(.body)
                }
            }
            if let failReason = common.failReason {
                if let hint = failReason.hint {
                    Text(hint)
                        .talerFont(.title3)
                }
            }
            if let abortReason = details.abortReason {
                if let exchangeResponse = abortReason.exchangeResponse,
                   let hint2 = exchangeResponse.hint {
                    Text(hint2)
                        .talerFont(.body)
                }
                if developerMode {
                    if let hint3 = abortReason.hint {
                        Text(hint3)
                            .talerFont(.body)
                    }
                }
            }
            if let choiceIndex = details.choiceIndex {
                if let contractTerms = details.contractTerms {
                    if let choices = contractTerms.choices,
                       choices.indices.contains(choiceIndex) {
                        let choice = choices[choiceIndex]
                        Text(choice.locDescription ?? "Index: \(choiceIndex)")   // fallback should never happen
                            .talerFont(.body)
                    }
                }
            }
        }
        if let products = terms?.products {
            if !products.isEmpty {
                Section {
                    ForEach(products) { product in
//                        if let productId = product.productId {
                        if let productName = product.productName {
                            Text(productName)
                                .talerFont(.body)
                        }
                    }
                }
            }
        }
    }
}

// MARK: -
//#Preview {
//    TransactionDetailV()
//}
