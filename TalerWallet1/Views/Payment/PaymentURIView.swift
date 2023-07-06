/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

// Will be called either by the user scanning a QR code or tapping the provided link,
// both from the shop's website. We show the payment details
struct PaymentURIView: View {
    private let symLog = SymLogV()
    let navTitle = String(localized: "Confirm Payment", comment:"pay merchant")

    @EnvironmentObject private var controller: Controller

    // the scanned URL
    let url: URL

    @EnvironmentObject private var model: WalletModel

    func acceptAction(detailsForUri: PaymentDetailsForUri) {
        Task {
            do {
                let confirmPayResult = try await model.confirmPayM(detailsForUri.transactionId)
                symLog.log(confirmPayResult as Any)
                if confirmPayResult.type != "done" {
                    controller.playSound(0)
                    // TODO: show error
                }
            } catch {
                controller.playSound(0)
                // TODO: error
                symLog.log(error.localizedDescription)
            }
            dismissTop()
        }
    }

    @State var detailsForUri: PaymentDetailsForUri? = nil

    var body: some View {
        if let detailsForUri {
          ScrollViewReader { scrollView in
            VStack {
                let baseURL = detailsForUri.contractTerms.exchanges.first?.url
                let raw = detailsForUri.amountRaw
                let effective = detailsForUri.amountEffective
                let currency = raw.currencyStr
                let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
                ThreeAmountsView(topTitle: String(localized: "Amount to pay:"),
                                topAmount: raw, fee: fee,
                              bottomTitle: String(localized: "\(currency) to be spent:"),
                             bottomAmount: effective,
                                    large: true, pending: false, incoming: false,
                                  baseURL: baseURL)
                // TODO: payment: popup with all possible exchanges, check fees
                .safeAreaInset(edge: .bottom) {
                    Button(navTitle, action: { acceptAction(detailsForUri: detailsForUri) })
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                }
            }
            .navigationTitle(navTitle)
          }
        } else {
            let badURL = "Error in URL: \(url)"
            WithdrawProgressView(message: url.host ?? badURL)
                .navigationTitle("Contacting Exchange")
                .task {
                    do {
                        symLog.log(".task")
                        let details = try await model.preparePayForUriM(url.absoluteString)
                        detailsForUri = details
                    } catch {    // TODO: error
                        symLog.log(error.localizedDescription)
                    }
                }
        }
    }
}
// MARK: -
struct PaymentURIView_Previews: PreviewProvider {
    static var previews: some View {
        let merchant = Merchant(name: "Merchant")
        let extra = Extra(articleName: "articleName")
        let product = Product(description: "description")
        let terms = MerchantContractTerms(hWire: "hWire",
                                          wireMethod: "wireMethod",
                                          summary: "summary",
                                            summaryI18n: nil,
                                          nonce: "nonce",
                                          amount: try! Amount(fromString: LONGCURRENCY + ":2.2"),
                                          payDeadline: Timestamp.tomorrow(),
                                          maxFee: try! Amount(fromString: LONGCURRENCY + ":0.2"),
                                          merchant: merchant,
                                          merchantPub: "merchantPub",
                                            deliveryDate: nil,
                                            deliveryLocation: nil,
                                          exchanges: [],
                                          products: [product],
                                          refundDeadline: Timestamp.tomorrow(),
                                          wireTransferDeadline: Timestamp.tomorrow(),
                                          timestamp: Timestamp.now(),
                                          orderID: "orderID",
                                          merchantBaseURL: "merchantBaseURL",
                                            fulfillmentURL: "fulfillmentURL",
                                            publicReorderURL: "publicReorderURL",
                                            fulfillmentMessage: nil,
                                            fulfillmentMessageI18n: nil,
                                          wireFeeAmortization: 0,
                                          maxWireFee: try! Amount(fromString: LONGCURRENCY + ":0.2"),
                                            minimumAge: nil,
                                          extra: extra
//                                          auditors: [],
                                  )
        let details = PaymentDetailsForUri(
            status: PreparePayResultType.paymentPossible,
            transactionId: "txn:payment:012345",
            contractTerms: terms,
            contractTermsHash: "termsHash",
            amountRaw: try! Amount(fromString: LONGCURRENCY + ":2.2"),
            amountEffective: try! Amount(fromString: LONGCURRENCY + ":2.4"),
            talerUri: "talerURI"
        )
        let url = URL(string: "taler://pay/some_amount")!
        
        PaymentURIView(url: url, detailsForUri: details)
    }
}
