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

typealias WithdrawDetails = WalletBackendGetWithdrawalDetailsForAmountRequest.Response
typealias TOSDetails = WalletBackendGetExchangeTermsOfService.Response

class ManualTransferModel: ObservableObject {
    let backend: WalletBackend
    let exchange: ExchangeItem
    var details: WithdrawDetails!
    var paytoUri: String!
    @Published var loading: Bool = false
    @Published var nav: Bool = false

    init(backend: WalletBackend, exchange: ExchangeItem) {
        self.backend = backend
        self.exchange = exchange
    }
    
    func loadDetails(_ newDetails: WithdrawDetails, _ newPaytoUri: String) {
        self.details = newDetails
        self.paytoUri = newPaytoUri
    }
}

class PromptWithdrawModel: ObservableObject {
    let backend: WalletBackend
    let exchange: ExchangeItem
    var details: WithdrawDetails!
    var tosDetails: TOSDetails?
    @Published var tosAccepted: Bool!
    @Published var loading: Bool = false
    @Published var navTos: Bool = false
    @Published var nav: Bool = false
    
    var manualTransferModel: ManualTransferModel
    
    init(backend: WalletBackend, exchange: ExchangeItem) {
        self.backend = backend
        self.exchange = exchange
        self.manualTransferModel = ManualTransferModel(backend: backend, exchange: exchange)
    }
    
    func loadDetails(_ newDetails: WithdrawDetails) {
        self.details = newDetails
        self.tosAccepted = details.tosAccepted
    }
    
    func acceptTos() {
        self.loading = true
        let req = WalletBackendSetExchangeTermsOfServiceAccepted(exchangeBaseUrl: exchange.exchangeBaseUrl,
                                                                 etag: tosDetails!.currentEtag)
        backend.sendFormattedRequest(request: req) { response, err in
            // TODO: Use Combine instead
            DispatchQueue.main.async {
                self.loading = false
                if let _ = response {
                    self.tosAccepted = true
                    self.navTos = false
                } else {
                    // TODO: Handle error.
                }
            }
        }
    }
    
    func acceptWithdraw() {
        // TODO: Include an option for a withdraw payto uri.
        self.loading = true
        let req = WalletBackendAcceptManualWithdrawalRequest(exchangeBaseUrl: exchange.exchangeBaseUrl,
                                                             amount: details.amountRaw)
        backend.sendFormattedRequest(request: req) { response, err in
            // TODO: Use Combine instead
            DispatchQueue.main.async {
                self.loading = false
                if let res = response {
                    self.manualTransferModel.loadDetails(self.details, res.exchangePaytoUris[0])
                    self.nav = true
                } else {
                    // TODO: Show error.
                    self.loading = false
                }
            }
        }
    }
}

class WithdrawModel: ObservableObject {
    let backend: WalletBackend
    let exchange: ExchangeItem
    var details: WithdrawDetails?
    @Published var loading: Bool = false
    @Published var nav: Bool = false
    
    var promptModel: PromptWithdrawModel
    
    init(backend: WalletBackend, exchange: ExchangeItem) {
        self.backend = backend
        self.exchange = exchange
        self.promptModel = PromptWithdrawModel(backend: backend, exchange: exchange)
    }
    
    func getWithdrawDetails(amountStr: String) {
        self.loading = true
        do {
            let amount = try Amount(fromString: amountStr)
            let req = WalletBackendGetWithdrawalDetailsForAmountRequest(exchangeBaseUrl: exchange.exchangeBaseUrl,
                                                                        amount: amount)
            backend.sendFormattedRequest(request: req) { response, err in
                // TODO: Use Combine instead.
                DispatchQueue.main.async {
                    if let res = response {
                        self.details = res
                        self.promptModel.loadDetails(res)
                        if res.tosAccepted {
                            self.loading = false
                            self.nav = true
                        } else {
                            self.getTos()
                        }
                    } else {
                        // TODO: Show error.
                        self.loading = false
                    }
                }
            }
        } catch {
            // TODO: Show error.
            self.loading = false
        }
    }
    
    private func getTos() {
        self.loading = true
        let req = WalletBackendGetExchangeTermsOfService(exchangeBaseUrl: exchange.exchangeBaseUrl)
        backend.sendFormattedRequest(request: req) { response, err in
            // TODO: Use Combine instead
            DispatchQueue.main.async {
                self.loading = false
                if let res = response {
                    self.promptModel.tosDetails = res
                    self.loading = false
                    self.nav = true
                } else {
                    // TODO: Show error.
                    self.loading = false
                }
            }
        }
    }
}
