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

typealias Announce = (_ this: String) -> ()

fileprivate func feeLabel(_ feeString: String) -> String {
    feeString.isEmpty ? EMPTYSTRING : String(localized: "+ \(feeString) fee")
}

/// The pay-template instantiation which already created an order at the merchant
struct PreparedTemplate: Equatable {
    let key: String                 // the parameters that order was created for
    let transactionId: String
}

// MARK: -
// Will be called either by the user scanning a <pay> QR code or tapping the provided link,
// both from the shop's website - or even from a printed QR code.
// We show the payment details in a sheet, and a "Confirm payment" / "Pay now" button.
// This is also the final view after the user entered data of a <pay-template>.
struct PaymentScan: View, Sendable {
    private let symLog = SymLogV(0)
    let stack: CallStack

    // the scanned URL
    let url: URL
    let template: Bool
    @Binding var amountToTransfer: Amount
    @Binding var summary: String
    let amountIsEditable: Bool                      //
    let summaryIsEditable: Bool                      //
    var prepared: Binding<PreparedTemplate?>? = nil // template only, lives in PayTemplateScan

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var currencyInfo: CurrencyInfo = CurrencyInfo.zero(UNKNOWN)
    @State private var txId: String? = nil

    @State private var elapsed: Int = 0
    @State private var talerTX = TalerTransaction(dummyCurrency: DEMOCURRENCY)

    /// the parameters an already instantiated template order belongs to
    private var templateKey: String {
        url.trimmedString + "\n"
          + (amountIsEditable ? amountToTransfer.description : EMPTYSTRING) + "\n"
          + (summaryIsEditable ? summary : EMPTYSTRING)
    }

    @MainActor
    private func viewDidLoad() async {
//        symLog.log(".task")
        if template {
            /// Instantiating a template creates a fresh order at the merchant, and this view is
            ///  pushed anew (with new @State) whenever the user navigates back and forward again
            ///  - so only instantiate once per amount/subject the user entered.
            let key = templateKey
            if let already = prepared?.wrappedValue, already.key == key {
                txId = already.transactionId
                return
            }
            if let templateResponse = try? await model.preparePayForTemplate(url.trimmedString,
                                                   amount: amountIsEditable ? amountToTransfer : nil,
                                                 summary: summaryIsEditable ? summary : nil) {
                txId = templateResponse.transactionId
                prepared?.wrappedValue = PreparedTemplate(key: key, transactionId: templateResponse.transactionId)
//                preparePayResult = templateResponse
//                let raw = templateResponse.amountRaw
//                controller.updateAmount(raw, forSaved: url)
            }
        } else {
            if let payResponse = try? await model.preparePayForUri(url.trimmedString) {
                txId = payResponse.transactionId
//                let raw = payResponse.amountRaw
//                controller.updateAmount(raw, forSaved: url)       // TODO: update scanned URL
            }
        }
    }

    var body: some View {
        ZStack {
            if let txId {
                TransactionSummaryList(stack: stack.push(),
                               transactionId: txId,
                                     talerTX: $talerTX,
                                    navTitle: nil,
                                     hasDone: true,                 // conclude payment
                                    showDone: .prominent,
                                         url: url,
                                 withActions: false)
#if TALER_NIGHTLY2
//            if let preparePayResult {
                let status = preparePayResult.status
                let paid = status == .alreadyConfirmed
                let navTitle = paid ? String(localized: "Already paid", comment:"pay merchant navTitle")
                                    : String(localized: "Confirm Payment", comment:"pay merchant navTitle")
                let list = List {
                    TransactionSummaryList.MerchantHeader(terms: terms)

                    if paid {
                        Text("You already paid for this article.")
                            .talerFont(.headline)
                        if let fulfillmentUrl = terms.fulfillmentURL {
                            if let destination = URL(string: fulfillmentUrl) {
                                let buttonTitle = terms.fulfillmentMessage ?? String(localized: "Open merchant website")
                                Link(buttonTitle, destination: destination)
                                    .buttonStyle(TalerButtonStyle(type: .bordered))
                                    .accessibilityHint(String(localized: "Will go to the merchant website.", comment: "a11y"))
                            }
                        }
                    } // You already paid

                }
                .listStyle(myListStyle.style).anyView
#if OIM
                .overlay { if #available(iOS 16.4, *) {
                    if controller.oimSheetActive {
                        OIMpayView(stack: stack.push(),
                                   amount: effective)
                    }
                } }
#endif

                if #available(iOS 17.0, *) {
                    list.toolbarTitleDisplayMode(.inlineLarge)
                } else {
                    list
                }
#endif
            } else {
                LoadingView(stack: stack.push(), scopeInfo: nil, message: url.host)
                    .task { await viewDidLoad() }
            }
        }.onAppear() {
            symLog.log("onAppear")
            DebugViewC.shared.setSheetID(SHEET_PAYMENT, stack: stack.push())
        }
    }
}
// MARK: -
// MARK: -
struct PaymentView2: View, Sendable {
    let stack: CallStack
    let paid: Bool
    let raw: Amount
    let effective: Amount?
    let firstScope: ScopeInfo?
    let baseURL: String?
//    let terms: MerchantContractTerms
    let summary: String?
    let products: [Product]?
    let balanceDetails: PaymentInsufficientBalanceDetails?

    func computeFee(raw: Amount?, eff: Amount?) -> Amount? {
        if let raw, let eff {
            return try! Amount.diff(raw, eff)      // TODO: different currencies
        }
        return nil
    }

    var body: some View {
                // TODO: show balanceDetails.balanceAvailable
                let topTitle = paid ? String(localized: "Paid amount:")
                                    : String(localized: "Amount to pay:")
                let topAbbrev =  paid ? String(localized: "Paid:", comment: "mini")
                                      : String(localized: "Pay:", comment: "mini")
                let bottomTitle = paid ? String(localized: "Spent amount:")
                                       : String(localized: "Amount to spend:")
                if let effective {  // payment possible
                    let fee = computeFee(raw: raw, eff: effective)
                    ThreeAmountsSection(stack: stack.push("PaymentView2"),
                                        scope: firstScope,
                                     topTitle: topTitle,
                                    topAbbrev: topAbbrev,
                                    topAmount: raw,
                                       noFees: nil,        // TODO: check baseURL for fees
                                          fee: fee,
                                feeIsNegative: nil,
                                  bottomTitle: bottomTitle,
                                 bottomAbbrev: String(localized: "Effective:", comment: "mini"),
                                 bottomAmount: effective,
                                        large: false,
                                pendingDialog: !paid,
                                       isDone: paid,
                                     incoming: false,
                                      baseURL: baseURL,
                                   txStateLcl: nil,
                                      summary: nil,     // summary already shown in PaymentView above choices
                                     products: products)
                    // TODO: payment: popup with all possible exchanges, check fees
                } else if let balanceDetails {    // Insufficient
                    if let localizedCause = balanceDetails.causeHint?.localizedCause(raw.currencyStr) {
                        Text(localizedCause)
                            .talerFont(.headline)
                    }
                    ThreeAmountsSection(stack: stack.push(),
                                        scope: firstScope,
                                     topTitle: topTitle,
                                    topAbbrev: topAbbrev,
                                    topAmount: raw,
                                       noFees: nil,        // TODO: check baseURL for fees
                                          fee: nil,
                                feeIsNegative: nil,
                                  bottomTitle: String(localized: "Amount available:"),
                                 bottomAbbrev: String(localized: "Available:", comment: "mini"),
                                 bottomAmount: balanceDetails.balanceAvailable,
                                        large: false,
                                pendingDialog: false,       // TODO: true to always show currency the payment will be made in?
                                       isDone: false,
                                     incoming: false,
                                      baseURL: baseURL,
                                   txStateLcl: nil,
                                      summary: nil,     // summary already shown in PaymentView above choices
                                     products: products)
                } else {
                    // TODO: Error - neither effective nor balanceDetails
                    Text("Error")
                        .talerFont(.body)
                }
    }
}
// MARK: -
struct PaySafeArea: View, Sendable {
    let symLog: SymLogV?
    let stack: CallStack
    let terms: MerchantContractTerms
    let amountString: String
    let amountA11y: String
    @Binding var payNow: Bool

    @EnvironmentObject private var controller: Controller

    @State private var wasTapped: Bool = false

    func timeToPay(_ terms: MerchantContractTerms) -> Int {
        if let milliseconds = try? terms.payDeadline.milliseconds() {
            let date = Date(milliseconds: milliseconds)
            let now = Date.now
            let timeInterval = now.timeIntervalSince(date)
            if timeInterval < 0 {
                symLog?.log("\(timeInterval) seconds left to pay")
                return Int(-timeInterval)
            } else {
                symLog?.log("\(date) - \(now) = \(timeInterval)")
            }
        } else {
            symLog?.log("no milliseconds")
        }
        return 0
    }

    var body: some View {
        let timeToPay = timeToPay(terms)
        let showTime = timeToPay > 0 && timeToPay < 300
        let button = Button("Pay \(amountString) now") {
            if !wasTapped {
                wasTapped = true
                controller.hapticNotification(.success)
                symLog?.log("paying \(amountString) now")
#if DEBUG       // 1 second delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    payNow = true
                }
#else
                payNow = true
#endif
            }
        }
            .accessibilityLabel(Text("Pay \(amountA11y) now", comment: "a11y"))
            .buttonStyle(TalerButtonStyle(type: .prominent, disabled: wasTapped))
            .disabled(wasTapped)
            .padding(.horizontal)

        if showTime {
            let view = VStack {
                TimeView(String(localized: "Time to pay:"),
                                  seconds: timeToPay)
                    .padding(.top)
                button
                    .padding(.bottom, 4)
            }
            if #available(iOS 26.0, *) {
                view
                    .glassEffect(in: .rect(cornerRadius: 16.0))
                    .padding(.horizontal)
            } else {
                view
            }
        } else {
            let _ = symLog?.log("\(timeToPay) not shown")
            button
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
