/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * Overview when there's more than 1 currency/exchange
 *
 * @author Marc Stibane
 */
import SwiftUI

struct TransactionPayDetailV: View {
    let paymentTx: PaymentTransaction

    var body: some View {
        let common = paymentTx.common
        let details = paymentTx.details
        let info = details.info
        Section {
            if let posConfirmation = details.posConfirmation {
                Text("Confirmation:", comment: "purchase may have a pos validation / confirmation")
                    .talerFont(.title3)
                    .listRowSeparator(.hidden)
                let totp = Text(posConfirmation)
                    .talerFont(.title1)
                if #available(iOS 17.7, *) {
                    let talerURI = posConfirmation
                    BorderWithNFC(talerURI: talerURI, nfcHint: true, size: 250, scanHints: nil) {
                        totp
                    }
                } else {
                    totp
                }
            }
//            Text(info.summary)
            Text("Order-ID:")
                .talerFont(.title3)
                .listRowSeparator(.hidden)
            Text(info.orderId)
                .talerFont(.body)
//            Text(info.merchant.name)

            if let fulfillmentUrl = info.fulfillmentUrl {
                if let destination = URL(string: fulfillmentUrl) {
                    let buttonTitle = info.fulfillmentMessage ?? String(localized: "Open merchant website")
                    Link(buttonTitle, destination: destination)
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .accessibilityHint(String(localized: "Will go to the merchant website.", comment: "a11y"))
                }
            } else if let fulfillmentMessage = info.fulfillmentMessage {
                Text(fulfillmentMessage)
                    .talerFont(.body)
            }
            if let products = info.products {
                ForEach(products) {product in
                    Section {
                        if let product_id = product.product_id {
                            Text(product_id)
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
