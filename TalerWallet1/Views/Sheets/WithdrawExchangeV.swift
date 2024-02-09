/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct WithdrawExchangeV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Checking Link")
    var url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @State private var exchangeBaseUrl: String?
    @State private var amountToTransfer = Amount.zero(currency: "")

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if let exchangeBaseUrl {
                ManualWithdraw(stack: stack.push(),
                     exchangeBaseUrl: exchangeBaseUrl,
                    amountToTransfer: $amountToTransfer)
            } else {
                // TODO: Error
                LoadingView(url: url, message: "No exchangeBaseUrl!")
            }
        }
        .task {
            do { // TODO: cancelled
                symLog.log(".task")
                let withdrawExchange = try await model.loadWithdrawalExchangeForUriM(url.absoluteString)
                let baseUrl = withdrawExchange.exchangeBaseUrl
                exchangeBaseUrl = baseUrl
                if let amount = withdrawExchange.amount {
                    amountToTransfer = amount
                } else {
                    // is already Amount.zero(currency: "")
                }
                // let the controller collect CurrencyInfo from this formerly unknown exchange
                let _ = await controller.getInfo(from: baseUrl, model: model)
            } catch {    // TODO: error
                symLog.log(error.localizedDescription)
                exchangeBaseUrl = nil
            }
        }
    }
}
