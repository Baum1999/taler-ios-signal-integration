/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */

import Foundation
import taler_swift

func paytoUriGetIban(uri: String) -> String {
    let url = URL(string: uri)!
    return url.lastPathComponent
}

func paytoUriGetSubject(uri: String) -> String {
    let url = URLComponents(string: uri)!
    return url.queryItems!.first(where: { item in
        item.name == "message"
    })!.value!.removingPercentEncoding!.replacingOccurrences(of: "+", with: " ")
}

class WithdrawModel: ObservableObject {
    enum State {
        case begin
        case loading
        case prompt(rawAmount: Amount,
                    effectiveAmount: Amount)
        case promptTOS(rawAmount: Amount,
                       effectiveAmount: Amount,
                       tos: String,
                       etag: String)
        case manualTransfer(rawAmount: Amount,
                            effectiveAmount: Amount,
                            paytoUri: String)
    }
    
    var backend: WalletBackend
    let exchange: ExchangeItem
    @Published var state: State
    
    init(backend: WalletBackend, exchange: ExchangeItem) {
        self.backend = backend
        self.exchange = exchange
        self.state = .begin
    }
    
    func getWithdrawDetails(amountStr: String) {
        self.state = .loading
        do {
            let amount = try Amount(fromString: amountStr)
            let req = WalletBackendGetWithdrawalDetailsForAmountRequest(exchangeBaseUrl: exchange.exchangeBaseUrl,
                                                                        amount: amount)
            backend.sendFormattedRequest(request: req) { response, err in
                // TODO: Use Combine instead.
                DispatchQueue.main.async {
                    if let res = response {
                        if res.tosAccepted {
                            self.state = .prompt(rawAmount: res.amountRaw, effectiveAmount: res.amountEffective)
                        } else {
                            self.getTos(rawAmount: res.amountRaw, effectiveAmount: res.amountEffective)
                        }
                    } else {
                        self.state = .begin
                        // TODO: Show error.
                    }
                }
            }
        } catch {
            self.state = .begin
            // TODO: Show error.
        }
    }
    
    private func getTos(rawAmount: Amount, effectiveAmount: Amount) {
        self.state = .loading
        let req = WalletBackendGetExchangeTermsOfService(exchangeBaseUrl: exchange.exchangeBaseUrl)
        backend.sendFormattedRequest(request: req) { response, err in
            // TODO: Use Combine instead
            DispatchQueue.main.async {
                if let res = response {
                    print(res)
                    self.state = .promptTOS(rawAmount: rawAmount,
                                            effectiveAmount: effectiveAmount,
                                            tos: res.content,
                                            etag: res.currentEtag)
                } else {
                    self.state = .begin
                    // TODO: Show error.
                }
            }
        }
    }
    
    func acceptTos() {
        let oldState = self.state
        self.state = .loading
        switch oldState {
        case .promptTOS(_, _, _, let etag):
            let req = WalletBackendSetExchangeTermsOfServiceAccepted(exchangeBaseUrl: exchange.exchangeBaseUrl,
                                                                     etag: etag)
            backend.sendFormattedRequest(request: req) { response, err in
                // TODO: Use Combine instead
                DispatchQueue.main.async {
                    self.state = oldState
                    // TODO: Handle error.
                }
            }
        default:
            self.state = oldState
            // TODO: Show error.
        }
    }
    
    func acceptWithdraw() {
        // TODO: Include an option for a withdraw payto uri.
        let oldState = self.state
        self.state = .loading
        switch oldState {
        case .prompt(let rawAmount, let effectiveAmount):
            let req = WalletBackendAcceptManualWithdrawalRequest(exchangeBaseUrl: exchange.exchangeBaseUrl,
                                                                 amount: rawAmount)
            backend.sendFormattedRequest(request: req) { response, err in
                // TODO: Use Combine instead
                DispatchQueue.main.async {
                    if let res = response {
                        // TODO: Error if there are no URIs.
                        self.state = .manualTransfer(rawAmount: rawAmount,
                                                     effectiveAmount: effectiveAmount,
                                                     paytoUri: res.exchangePaytoUris[0])
                    } else {
                        // TODO: Handle error.
                        self.state = oldState
                    }
                }
            }
        default:
            self.state = oldState
            // TODO: Show error.
        }
    }
}
