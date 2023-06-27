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

    // the scanned URL
    let url: URL

    @EnvironmentObject private var model: WalletModel


    func playSound(success: Bool) {
        let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/payment_"
                      + (success ? "success.caf" : "failure.caf"))
        GNU_Taler.playSound(fileURL: url)
    }

    func acceptAction(detailsForUri: PaymentDetailsForUri) {
        Task {
            do {
                let confirmPayResult = try await model.confirmPayM(detailsForUri.proposalId)
                symLog.log(confirmPayResult as Any)
                if confirmPayResult.type == "done" {
                    playSound(success: true)
                    // TODO: Show Hints that Payment was successfull
                } else {
                    playSound(success: false)
                    // TODO: show error
                }
            } catch {
                playSound(success: false)
                // TODO: error
                symLog.log(error.localizedDescription)
            }
            dismissTop()
        }
    }

    @State var detailsForUri: PaymentDetailsForUri? = nil

    var body: some View {
        if let detailsForUri {
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
        let url = URL(string: "taler://pay/some_amount")!
        
        PaymentURIView(url: url, detailsForUri: details)
    }
}
