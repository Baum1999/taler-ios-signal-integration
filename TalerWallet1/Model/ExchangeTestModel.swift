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
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

fileprivate let DEMO_EXCHANGEBASEURL = "https://exchange.demo.taler.net/"
fileprivate let DEMO_BANKBASEURL = "https://bank.demo.taler.net/"
fileprivate let DEMO_BANKAPIBASEURL = "https://bank.demo.taler.net/demobanks/default/access-api/"
fileprivate let DEMO_MERCHANTBASEURL = "https://backend.demo.taler.net/"
fileprivate let DEMO_MERCHANTAUTHTOKEN = "secret-token:sandbox"

// MARK: -
class ExchangeTestModel: WalletModel {
}
// MARK: -
extension ExchangeTestModel {
    @MainActor func loadTestKudos() async throws {
        do {
            let amount = Amount(currency: "KUDOS", integer: 11, fraction: 0)
            let request = WalletBackendWithdrawTestBalance(amount: amount,
                                                      bankBaseUrl: DEMO_BANKBASEURL,
                                                  exchangeBaseUrl: DEMO_EXCHANGEBASEURL,
                                             bankAccessApiBaseUrl: DEMO_BANKAPIBASEURL)
            let response = try await sendRequest(request, ASYNCDELAY)
            symLog?.log("received: \(response)")
        } catch {
            throw error
        }
    }

    @MainActor func runIntegrationTest() async throws {
        do {
            let amountW = Amount(currency: "KUDOS", integer: 3, fraction: 0)
            let amountS = Amount(currency: "KUDOS", integer: 1, fraction: 0)
            let request = WalletBackendRunIntegration(amountToWithdraw: amountW,
                                                         amountToSpend: amountS,
                                                           bankBaseUrl: DEMO_BANKAPIBASEURL,
                                                       exchangeBaseUrl: DEMO_EXCHANGEBASEURL,
                                                       merchantBaseUrl: DEMO_MERCHANTBASEURL,
                                                     merchantAuthToken: DEMO_MERCHANTAUTHTOKEN)
            let response = try await sendRequest(request, ASYNCDELAY)
            symLog?.log("received: \(response)")
        } catch {
            throw error
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
