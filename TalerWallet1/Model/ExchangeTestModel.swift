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
import SymLog

fileprivate let EXCHANGEBASEURL = "https://exchange.demo.taler.net/"
fileprivate let BANKBASEURL = "https://bank.demo.taler.net/"
fileprivate let BANKACCESSAPIBASEURL = "https://bank.demo.taler.net/demobanks/default/access-api/"
fileprivate let MERCHANTBASEURL = "https://backend.demo.taler.net/"
fileprivate let MERCHANTAUTHTOKEN = "secret-token:sandbox"

// MARK: -
class ExchangeTestModel: ObservableObject {
    private let symLog = SymLogC(0)

    var walletCore: WalletCore
    
    @Published var loading: Bool = false
    
    init(walletCore: WalletCore) {
        self.walletCore = walletCore
    }
}
// MARK: -
extension ExchangeTestModel {
    func loadTestKudos() {
        loading = true
        
        let amount = Amount(currency: "KUDOS", integer: 11, fraction: 0)
        let req = WalletBackendWithdrawTestBalance(amount: amount, bankBaseUrl: BANKBASEURL,
                        exchangeBaseUrl: EXCHANGEBASEURL, bankAccessApiBaseUrl: BANKACCESSAPIBASEURL)
        symLog.log("sending: \(req)")
        walletCore.sendFormattedRequest(request: req) { response, err in
            DispatchQueue.main.async {
                self.loading = false
                if let res = response {
                    // TODO: ?
                    self.symLog.log("received: \(res)")
                } else {
                    // TODO: Handle error
                }
            }
        }
    }

    func runIntegrationTest() {
        loading = true

        let amountW = Amount(currency: "KUDOS", integer: 3, fraction: 0)
        let amountS = Amount(currency: "KUDOS", integer: 1, fraction: 0)
        let req = WalletBackendRunIntegration(amountToWithdraw: amountW,
                                              amountToSpend: amountS,
                                              bankBaseUrl: BANKACCESSAPIBASEURL,
                                              exchangeBaseUrl: EXCHANGEBASEURL,
                                              merchantBaseUrl: MERCHANTBASEURL,
                                              merchantAuthToken: MERCHANTAUTHTOKEN
        )
        symLog.log("sending: \(req)")
        walletCore.sendFormattedRequest(request: req) { response, err in
            DispatchQueue.main.async {
                self.loading = false
                if let res = response {
                    // TODO: ?
                    self.symLog.log("received: \(res)")
                } else {
                    // TODO: Handle error
                }
            }
        }
    }
}

/// A request to add a test balance to the wallet.
fileprivate struct WalletBackendWithdrawTestBalance: WalletBackendFormattedRequest {
    typealias Response = String
    func operation() -> String { return "withdrawTestBalance" }
    func args() -> Args {
        return Args(amount: amount, bankBaseUrl: bankBaseUrl,
                    exchangeBaseUrl: exchangeBaseUrl, bankAccessApiBaseUrl: bankAccessApiBaseUrl)
    }

    var amount: Amount
    var bankBaseUrl: String
    var exchangeBaseUrl: String
    var bankAccessApiBaseUrl: String

    struct Args: Encodable {
        var amount: Amount
        var bankBaseUrl: String
        var exchangeBaseUrl: String
        var bankAccessApiBaseUrl: String
    }
}

/// A request to add a test balance to the wallet.
fileprivate struct WalletBackendRunIntegration: WalletBackendFormattedRequest {
    typealias Response = String
    func operation() -> String { return "runIntegrationTest" }
    func args() -> Args {
        return Args(amountToWithdraw: amountToWithdraw,
                    amountToSpend: amountToSpend,
                    bankBaseUrl: bankBaseUrl,
                    exchangeBaseUrl: exchangeBaseUrl,
                    merchantBaseUrl: merchantBaseUrl,
                    merchantAuthToken: merchantAuthToken
        )
    }

    var amountToWithdraw: Amount
    var amountToSpend: Amount
    var bankBaseUrl: String
    var exchangeBaseUrl: String
    var merchantBaseUrl: String
    var merchantAuthToken: String

    struct Args: Encodable {
        var amountToWithdraw: Amount
        var amountToSpend: Amount
        var bankBaseUrl: String
        var exchangeBaseUrl: String
        var merchantBaseUrl: String
        var merchantAuthToken: String
    }
}
