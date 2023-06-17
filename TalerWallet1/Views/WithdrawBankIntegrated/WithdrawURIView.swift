/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

// Will be called either by the user scanning a QR code or tapping the provided link, both from the bank's website
// we show the user the withdrawal details - but first the ToS must be accepted
// after the user confirmed the withdrawal, we remind them to return to the bank website to confirm there, too
struct WithdrawURIView: View {
    private let symLog = SymLogV()
    // the URL from the bank website
    var url: URL

    let model = WithdrawModel.model(baseURL: "global")      // TODO: get baseURL from URL

    // the exchange used for this withdrawal.
    @State var exchangeBaseUrl: String = ""
    @State var manualWithdrawalDetails: ManualWithdrawalDetails?
    @State var didAcceptTOS: Bool = false

    var body: some View {
        let badURL = "Error in URL: \(url)"
        VStack {
            if !didAcceptTOS {      // user must accept ToS first
                WithdrawTOSView(exchangeBaseUrl: exchangeBaseUrl,
                                          model: model,
                                         viewID: SHEET_WITHDRAW_TOS) {
                    didAcceptTOS = true
                }
            } else {                // show Amount details and let user accept
                WithdrawAcceptView(url: url, model: model,
                                   detailsForAmount: manualWithdrawalDetails!,
                                   baseURL: exchangeBaseUrl)
            }
        }
        .overlay {
            if !exchangeBaseUrl.hasPrefix(HTTPS) {
                WithdrawProgressView(message: url.host ?? badURL)
                    .navigationTitle("Contacting Exchange")
            } else if manualWithdrawalDetails == nil {
                WithdrawProgressView(message: exchangeBaseUrl.trimURL())
                    .navigationTitle("Found Exchange")
            }
        }
        .onAppear() {
            DebugViewC.shared.setSheetID(SHEET_WITHDRAWAL)
        }
        .task {
            do { // TODO: cancelled
                symLog.log(".task")
                let withdrawUriInfo = try await model.loadWithdrawalDetailsForUriM(url.absoluteString)
                let amount = withdrawUriInfo.amount
                if let baseURL = withdrawUriInfo.defaultExchangeBaseUrl {
                    exchangeBaseUrl = baseURL
                } else if let first = withdrawUriInfo.possibleExchanges.first {
                    exchangeBaseUrl = first.exchangeBaseUrl
                }
                if exchangeBaseUrl.hasPrefix(HTTPS) {
                    symLog.log("amount: \(amount), baseURL: \(String(describing: exchangeBaseUrl))")
                    // TODO: let user choose exchange from list
                    manualWithdrawalDetails = try await model.loadWithdrawalDetailsForAmountM(exchangeBaseUrl, amount: amount)
                    symLog.log("raw: \(manualWithdrawalDetails!.amountRaw), effective: \(manualWithdrawalDetails!.amountEffective)")
                    if manualWithdrawalDetails!.tosAccepted {
                        didAcceptTOS = true
                    }
                } else {
                    // TODO: error no exchange!
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }
}
