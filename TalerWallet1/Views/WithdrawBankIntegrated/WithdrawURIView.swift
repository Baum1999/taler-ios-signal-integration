/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import SymLog

struct WithdrawURIView: View {
    private let symLog = SymLogV()
    var url: URL
    @ObservedObject var model: WithdrawModel

//    @State var withdrawUriInfo: WithdrawUriInfoResponse?
    @State var exchangeBaseUrl: String?
    @State var manualWithdrawalDetails: ManualWithdrawalDetails?
    @State var didAcceptTOS: Bool = false

    var body: some View {
        let badURL = "Error in URL: \(url)"
        VStack {
            let currState = model.withdrawState
            if currState == nil {
                LoadingView(backButtonHidden: false)
            } else {
                let _ = symLog.vlog(currState as Any)
                switch currState {
                    case .waitingForUriDetails, .receivedUriDetails:
                        WithdrawProgressView(message: url.host ?? badURL)
                            .navigationTitle("Contacting Exchange")
                    case .waitingForAmountDetails:
                        WithdrawProgressView(message: exchangeBaseUrl?.trimURL() ?? badURL)
                            .navigationTitle("Found Exchange")
                    default:
                    // .receivedAmountDetails, .waitingForTOS, .receivedTOS, .waitingForTOSAck, .receivedTOSAck
                    // waitingForWithdrAck, receivedWithdrAck
                        if !didAcceptTOS {
                            // user must accept ToS first
                            WithdrawTOSView(exchangeBaseUrl: exchangeBaseUrl!,
                                                      model: model,
                                                     viewID: SHEET_WITHDRAW_TOS) {
                                didAcceptTOS = true
                            }
                        } else {
                            // show Amount details and let user accept
                            WithdrawAcceptView(url: url, model: model,
                                              detailsForAmount: manualWithdrawalDetails!,
                                                       baseURL: exchangeBaseUrl!)
                        }
                }
            }
        }.onAppear() {
            DebugViewC.shared.setSheetID(SHEET_WITHDRAWAL)
        }.task {
            do { // TODO: cancelled
                symLog.log(".task")
                let withdrawUriInfo = try await model.loadWithdrawalDetailsForUriM(url.absoluteString)
                let amount = withdrawUriInfo.amount
                if let baseURL = withdrawUriInfo.defaultExchangeBaseUrl {
                    exchangeBaseUrl = baseURL
                } else {
                    exchangeBaseUrl = withdrawUriInfo.possibleExchanges.first?.exchangeBaseUrl
                }
                symLog.log("amount: \(amount), baseURL: \(String(describing: exchangeBaseUrl))")
                // TODO: let user choose exchange from list
                manualWithdrawalDetails = try await model.loadWithdrawalDetailsForAmountM(exchangeBaseUrl!, amount: amount)

                symLog.log("raw: \(manualWithdrawalDetails!.amountRaw), effective: \(manualWithdrawalDetails!.amountEffective)")
                if manualWithdrawalDetails!.tosAccepted {
                    didAcceptTOS = true
                }
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
            }
        }
    }
}
