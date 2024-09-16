/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

typealias Announce = (_ this: String) -> ()

fileprivate func feeLabel(_ feeString: String) -> String {
    feeString.count > 0 ? String(localized: "+ \(feeString) fee")
    : EMPTYSTRING
}

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

/// at the moment the merchant doesn't provide live fee updates, but only after creating the payment. Thus we cannot show life fees...
//struct PayForTemplateResult {
//    let ppCheck: PreparePayResult
//    let insufficient: Bool
//    let feeAmount: Amount?
//    let feeStr: String
//}
//
//func preparePayForTemplate(model: WalletModel,
//                             url: URL,
//                          amount: Amount?,
//                         summary: String?,
//                        announce: Announce)
//  async -> PayForTemplateResult? {
//    if let ppCheck = try? await model.preparePayForTemplateM(url.absoluteString, amount: amount, summary: summary) {
//        let controller = Controller.shared
//        let amountRaw = ppCheck.amountRaw
//        let currency = amountRaw.currencyStr
//        let currencyInfo = controller.info(for: currency, controller.currencyTicker)
//        let amountVoiceOver = amountRaw.formatted(currencyInfo, isNegative: false)
//        let insufficient = ppCheck.status == .insufficientBalance
//        if let feeAmount = templateFee(ppCheck: ppCheck) {
//            let feeStr = feeAmount.formatted(currencyInfo, isNegative: false)
//            let feeLabel = feeLabel(feeStr)
//            announce("\(amountVoiceOver), \(feeLabel)")
//            return PayForTemplateResult(ppCheck: ppCheck, insufficient: insufficient,
//                                        feeAmount: feeAmount, feeStr: feeStr)
//        }
//        announce(amountVoiceOver)
//        return PayForTemplateResult(ppCheck: ppCheck, insufficient: insufficient,
//                                    feeAmount: nil, feeStr: EMPTYSTRING)
//    }
//    return nil
//}

// MARK: -
// Will be called either by the user scanning a QR code or tapping the provided link,
// both from the shop's website. We show the payment details in a sheet.
struct PaymentView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack

    // the scanned URL
    let url: URL
    let template: Bool
    @Binding var amountToTransfer: Amount
    @Binding var summary: String
    let amountIsEditable: Bool                      //
    let summaryIsEditable: Bool                      //

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State var preparePayResult: PreparePayResult? = nil


    func checkCurrencyInfo(for result: PreparePayResult) async {
        let exchanges = result.contractTerms.exchanges
        for exchange in exchanges {
            let baseUrl = exchange.url
            if let someExchange = try? await model.getExchangeByUrl(url: baseUrl) {
                symLog.log("\(baseUrl.trimURL()) loaded")
                await controller.checkCurrencyInfo(for: baseUrl, model: model)
                symLog.log("Info(for: \(baseUrl.trimURL())) loaded")
                return
            }
        }
        symLog.log("Couldn't load Info(for: \(result.amountRaw.currencyStr))")
    }

    var body: some View {
      Group {
        if let preparePayResult {
            let status = preparePayResult.status
            let raw = preparePayResult.amountRaw
            let currency = raw.currencyStr
            let effective = preparePayResult.amountEffective
            let terms = preparePayResult.contractTerms
            let baseURL = terms.exchanges.first?.url
            let paid = status == .alreadyConfirmed
            let navTitle = paid ? String(localized: "Already paid", comment:"pay merchant navTitle")
                                : String(localized: "Confirm Payment", comment:"pay merchant navTitle")
            List {
                if paid {
                    Text("You already paid for this article.")
                        .talerFont(.headline)
                    if let fulfillmentUrl = terms.fulfillmentURL {
                        if let destination = URL(string: fulfillmentUrl) {
                            let buttonTitle = terms.fulfillmentMessage ?? String(localized: "Open merchant website")
                            Link(buttonTitle, destination: destination)
                                .buttonStyle(TalerButtonStyle(type: .bordered))
                                .accessibilityHint(String(localized: "Will go to the merchant website."))
                        }
                    }
                }
                // TODO: show balanceDetails.balanceAvailable
                let topTitle = paid ? String(localized: "Paid amount:")
                                    : String(localized: "Amount to pay:")
                let topAbbrev =  paid ? String(localized: "Paid:", comment: "mini")
                                      : String(localized: "Pay:", comment: "mini")
                let bottomTitle = paid ? String(localized: "Spent amount:")
                                       : String(localized: "Amount to spend:")
                if let effective {
                    let fee = try! Amount.diff(raw, effective)      // TODO: different currencies
                    ThreeAmountsSection(stack: stack.push(),
                                 currencyInfo: $currencyInfo,
                                     topTitle: topTitle,
                                    topAbbrev: topAbbrev,
                                    topAmount: raw,
                                       noFees: nil,        // TODO: check baseURL for fees
                                          fee: fee,
                                  bottomTitle: bottomTitle,
                                 bottomAbbrev: String(localized: "Effective:", comment: "mini"),
                                 bottomAmount: effective,
                                        large: false,
                                      pending: false,
                                     incoming: false,
                                      baseURL: baseURL,
                                   txStateLcl: nil,
                                      summary: terms.summary,
                                     merchant: terms.merchant.name)
                    // TODO: payment: popup with all possible exchanges, check fees
                } else if let balanceDetails = preparePayResult.balanceDetails {    // Insufficient
                    Text("You don't have enough \(currency).")
                        .talerFont(.headline)
                    ThreeAmountsSection(stack: stack.push(),
                                 currencyInfo: $currencyInfo,
                                     topTitle: topTitle,
                                    topAbbrev: topAbbrev,
                                    topAmount: raw,
                                       noFees: nil,        // TODO: check baseURL for fees
                                          fee: nil,
                                  bottomTitle: String(localized: "Amount available:"),
                                 bottomAbbrev: String(localized: "Available:", comment: "mini"),
                                 bottomAmount: balanceDetails.balanceAvailable,
                                        large: false,
                                      pending: false,
                                     incoming: false,
                                      baseURL: baseURL,
                                   txStateLcl: nil,
                                      summary: terms.summary,
                                     merchant: terms.merchant.name)
                } else {
                    // TODO: Error - neither effective nor balanceDetails
                    Text("Error")
                        .talerFont(.body)
                }
            }
            .listStyle(myListStyle.style).anyView
            .safeAreaInset(edge: .bottom) {
                if !paid {
                    if let effective {
                        VStack {
                            NavigationLink(destination: LazyView {
                                PaymentDone(stack: stack.push(),
                                            currencyInfo: $currencyInfo,
                                            transactionId: preparePayResult.transactionId)
                            }) {
                                let formatted = raw.formatted(currencyInfo, isNegative: false)
                                Text("Pay \(formatted) now")
                            }
                                .buttonStyle(TalerButtonStyle(type: .prominent))
                                .padding(.horizontal)
                            Text("Payment is made in \(currencyInfo.scope.currency)")
                                .talerFont(.callout)
                        }
                    } else {
                        Button("Cancel") {
                            dismissTop(stack.push())
                        }
                            .buttonStyle(TalerButtonStyle(type: .bordered))
                            .padding(.horizontal)
                    } // Cancel
                }
            }
            .navigationTitle(navTitle)
            .task(id: controller.currencyTicker) {
                let currency = amountToTransfer.currencyStr
                currencyInfo = controller.info(for: currency, controller.currencyTicker)
                symLog.log("Info(for: \(currency)) loaded: \(currencyInfo.scope.currency)")
//                currencyName = currencyInfo.scope.currency
            }
        } else {
            LoadingView(scopeInfo: nil, message: url.host)
            .task { // this runs only once
                symLog.log(".task")
                if template {
                    if let result = try? await model.preparePayForTemplateM(url.absoluteString,
                                                                     amount: amountIsEditable ? amountToTransfer : nil,
                                                                    summary: summaryIsEditable ? summary : nil) {
                        await checkCurrencyInfo(for: result)
                        preparePayResult = result
                    }
                } else {
                    if let result = try? await model.preparePayForUriM(url.absoluteString) {
                        amountToTransfer = result.amountRaw
                        await checkCurrencyInfo(for: result)
                        preparePayResult = result
                    }
                }
            }
        }
      }.onAppear() {
          symLog.log("onAppear")
          DebugViewC.shared.setSheetID(SHEET_PAYMENT)
      }
    }
}
// MARK: -
#if false
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
                                         amount: Amount(currency: LONGCURRENCY, cent: 220),
                                    payDeadline: Timestamp.tomorrow(),
                                         maxFee: Amount(currency: LONGCURRENCY, cent: 20),
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
                                     maxWireFee: Amount(currency: LONGCURRENCY, cent: 20),
                                     minimumAge: nil
//                                        extra: extra,
//                                     auditors: []
                                  )
        let details = PreparePayResult(status: PreparePayResultType.paymentPossible,
                                transactionId: "txn:payment:012345",
                                contractTerms: terms,
                            contractTermsHash: "termsHash",
                                    amountRaw: Amount(currency: LONGCURRENCY, cent: 220),
                              amountEffective: Amount(currency: LONGCURRENCY, cent: 240),
                               balanceDetails: nil,
                                         paid: nil
//                               ,   talerUri: "talerURI"
        )
        let url = URL(string: "taler://pay/some_amount")!
        
//        @State private var amount: Amount? = nil        // templateParam
//        @State private var summary: String? = nil       // templateParam

        PaymentView(stack: CallStack("Preview"), url: url,
                 template: false, amountToTransfer: nil, summary: nil,
         amountIsEditable: false, summaryIsEditable: false,
         preparePayResult: details)
    }
}
#endif
