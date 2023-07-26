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
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    // the scanned URL
    let url: URL

    @EnvironmentObject private var model: WalletModel

    func acceptAction(preparePayResult: PreparePayResult) {
        Task {
            do {
                let confirmPayResult = try await model.confirmPayM(preparePayResult.transactionId)
//                symLog.log(confirmPayResult as Any)
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

    @State var preparePayResult: PreparePayResult? = nil

    var body: some View {
        if let preparePayResult {
            let effective = preparePayResult.amountEffective
            List {
                let baseURL = preparePayResult.contractTerms.exchanges.first?.url
                let raw = preparePayResult.amountRaw
                let currency = raw.currencyStr
                let topTitle = String(localized: "Amount to pay:")
                if let effective {
                    // TODO: already paid
                    let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
                    ThreeAmountsView(topTitle: topTitle,
                                     topAmount: raw, fee: fee,
                                     bottomTitle: String(localized: "\(currency) to be spent:"),
                                     bottomAmount: effective,
                                     large: false, pending: false, incoming: false,
                                     baseURL: baseURL)
                    // TODO: payment: popup with all possible exchanges, check fees
                } else if let balanceDetails = preparePayResult.balanceDetails {    // Insufficient
                    Text("You don't have enough \(currency)")
                    ThreeAmountsView(topTitle: topTitle,
                                     topAmount: raw, fee: nil,
                                     bottomTitle: String(localized: "\(currency) available:"),
                                     bottomAmount: balanceDetails.balanceAvailable,
                                     large: false, pending: false, incoming: false,
                                     baseURL: baseURL)
                } else {
                    // TODO: Error - neither effective nor balanceDetails
                    Text("Error")
                }
            }
            .listStyle(myListStyle.style).anyView
            .safeAreaInset(edge: .bottom) {
                if let effective {
                    Button(navTitle, action: { acceptAction(preparePayResult: preparePayResult) })
                        .buttonStyle(TalerButtonStyle(type: .prominent))
                        .padding(.horizontal)
                } else {
                    Button("Cancel", action: { dismissTop() })
                        .buttonStyle(TalerButtonStyle(type: .bordered))
                        .padding(.horizontal)
                }
            }
            .navigationTitle(navTitle)
        } else {
            let badURL = "Error in Link: \(url)"
            WithdrawProgressView(message: url.host ?? badURL)
                .navigationTitle("Find Exchange")
                .task {
                    do {
                        symLog.log(".task")
                        let result = try await model.preparePayForUriM(url.absoluteString)
                        preparePayResult = result
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
        let details = PreparePayResult(
            status: PreparePayResultType.paymentPossible,
            transactionId: "txn:payment:012345",
            contractTerms: terms,
            contractTermsHash: "termsHash",
            amountRaw: try! Amount(fromString: LONGCURRENCY + ":2.2"),
            amountEffective: try! Amount(fromString: LONGCURRENCY + ":2.4"),
            balanceDetails: nil,
            paid: nil
//        ,   talerUri: "talerURI"
        )
        let url = URL(string: "taler://pay/some_amount")!
        
        PaymentURIView(url: url, preparePayResult: details)
    }
}
