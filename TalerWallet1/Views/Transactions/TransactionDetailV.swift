//
//  TransactionDetailV.swift
//  TalerWallet
//
//  Created by Marc Stibane on 2024-01-28.
//  Copyright © 2024 Taler. All rights reserved.
//

import SwiftUI

struct TransactionDetailV: View {
    let paymentTx: PaymentTransaction

    var body: some View {
        let common = paymentTx.common
        let details = paymentTx.details
        let info = details.info
        Section {
            if let posConfirmation = details.posConfirmation {
                Text(posConfirmation)
            }
//            Text(info.summary)
            Text(info.orderId)
//            Text(info.merchant.name)

            if let fulfillmentUrl = info.fulfillmentUrl {
                if let destination = URL(string: fulfillmentUrl) {
                    let buttonTitle = info.fulfillmentMessage ?? "Open merchant website"
                    Link(buttonTitle, destination: destination)
                        .buttonStyle(TalerButtonStyle(type: .bordered))
                        .accessibilityHint("Will go to the merchant website.")
                }
            } else if let fulfillmentMessage = info.fulfillmentMessage {
                Text(fulfillmentMessage)
            }
            if let products = info.products {
                ForEach(products) {product in
                    Section {
                        if let product_id = product.product_id {
                            Text(product_id)
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
