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

struct WithdrawExchangeV: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle = String(localized: "Checking Link")
    var url: URL

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
    @State private var amountToTransfer = Amount.zero(currency: "")
    @State private var exchange: Exchange? = nil

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Group {
            if exchange != nil {
                ManualWithdraw(stack: stack.push(), isSheet: true,
                     exchangeBaseUrl: exchange!.exchangeBaseUrl,
                            exchange: $exchange,
                    amountToTransfer: $amountToTransfer)
            } else {
                // TODO: Error
                LoadingView(url: url, message: "No exchangeBaseUrl!")
            }
        }
        .task {
            if exchange == nil {
                do { // TODO: cancelled
                    symLog.log(".task")
                    let withdrawExchange = try await model.loadWithdrawalExchangeForUriM(url.absoluteString)
                    let baseUrl = withdrawExchange.exchangeBaseUrl
                    symLog.log("getExchangeByUrl(\(baseUrl))")
                    if let exc = await model.getExchangeByUrl(url: baseUrl) {
                        // let the controller collect CurrencyInfo from this formerly unknown exchange
                        let _ = await controller.getInfo(from: baseUrl, model: model)
                        if let amount = withdrawExchange.amount {
                            amountToTransfer = amount
                        } else {
                            let currency = exc.scopeInfo?.currency
                                        ?? exc.currency
                                        ?? String(localized: "Unknown", comment: "unknown currency")
                            amountToTransfer.setCurrency(currency)
                            // is already Amount.zero(currency: "")
                        }
                        exchange = exc
                    } else {
                        // TODO: Error "Can't get Exchange / Payment Service Provider Info"
                    }
                } catch {    // TODO: error
                    symLog.log(error.localizedDescription)
                    exchange = nil
                }
            }
        }
    }
}
