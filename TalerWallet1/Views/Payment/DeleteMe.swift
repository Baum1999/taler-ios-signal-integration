/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import AVFoundation
import SymLog

struct PaymentAcceptView: View {
    private let symLog = SymLogV()

    let detailsForUri: PaymentDetailsForUri
    let acceptAction: () -> Void

    let navTitle = String(localized: "Accept Payment")

    @State private var disabled = false
    var body: some View {
        Group {
            let raw = detailsForUri.amountRaw
            let effective = detailsForUri.amountEffective
            let currency = raw.currencyStr
            let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
            ThreeAmountsView(topTitle: String(localized: "Amount to pay:"),
                             topAmount: raw, fee: fee,
                             bottomTitle: String(localized: "\(currency) to be spent:"),
                             bottomAmount: effective,
                             large: true, pending: false, incoming: false,
                             baseURL: detailsForUri.contractTerms.exchanges.first?.url)
                // TODO: payment: popup with all possible exchanges, check fees
            .safeAreaInset(edge: .bottom) {
                Button(String(localized: "Accept"), action: acceptAction)
                    .buttonStyle(TalerButtonStyle(type: .prominent))
                    .padding(.horizontal)
            }
        }
            .navigationTitle(navTitle)
    }
}
// MARK: -
struct PaymentAccept_Previews: PreviewProvider {
    static var previews: some View {
        let merchant = Merchant(name: "Merchant")
        let extra = Extra(articleName: "articleName")
        let product = Product(description: "description")
        let terms = ContractTerms(amount: try! Amount(fromString: LONGCURRENCY + ":2.2"),
                                  maxFee: try! Amount(fromString: LONGCURRENCY + ":0.2"),
                                  maxWireFee: try! Amount(fromString: LONGCURRENCY + ":0.2"),
                                  merchant: merchant,
                                  extra: extra,
                                  summary: "summary",
                                  timestamp: Timestamp.now(),
                                  payDeadline: Timestamp.tomorrow(),
                                  refundDeadline: Timestamp.tomorrow(),
                                  wireTransferDeadline: Timestamp.tomorrow(),
                                  merchantBaseURL: "merchantBaseURL",
                                  fulfillmentURL: "fulfillmentURL",
                                  publicReorderURL: "publicReorderURL",
                                  auditors: [],
                                  exchanges: [],
                                  orderID: "orderID",
                                  nonce: "nonce",
                                  merchantPub: "merchantPub",
                                  products: [product],
                                  hWire: "hWire",
                                  wireMethod: "wireMethod",
                                  wireFeeAmortization: 0)
        let details = PaymentDetailsForUri(
            amountRaw: try! Amount(fromString: LONGCURRENCY + ":2.2"),
            amountEffective: try! Amount(fromString: LONGCURRENCY + ":2.4"),
            noncePriv: "noncePriv",
            proposalId: "proposalId",
            contractTerms: terms,
            contractTermsHash: "termsHash"
        )
        PaymentAcceptView(detailsForUri: details, acceptAction: {})
    }
}
