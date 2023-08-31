/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

fileprivate let APIBASEURL  = "/demobanks/default/access-api/"
//fileprivate let MERCHANTAUTHTOKEN = "secret-token:sandbox"
fileprivate let MERCHANTAUTHTOKEN = "secret-token:secret"

// MARK: -
/// A request to add a test balance to the wallet.
fileprivate struct WalletBackendWithdrawTestBalance: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
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
extension WalletModel {
    @MainActor func loadTestKudosM(test: Bool)
    async throws {          // M for MainActor
        let amount = Amount(currency:  test ? TESTCURRENCY : DEMOCURRENCY, integer: 11, fraction: 0)
        let request = WalletBackendWithdrawTestBalance(amount: amount,
                                                       bankBaseUrl: test ? TESTBANK : DEMOBANK,
                                                       exchangeBaseUrl: test ? TESTEXCHANGE : DEMOEXCHANGE,
                                                       bankAccessApiBaseUrl: (test ? TESTBANK : DEMOBANK) + APIBASEURL)
        let response = try await sendRequest(request, ASYNCDELAY)
    }
} // loadTestKudosM()
// MARK: -
/// A request to add a test balance to the wallet.
fileprivate struct WalletBackendRunIntegration: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { return newVersion ? "runIntegrationTestV2" : "runIntegrationTest" }
    func args() -> Args {
        return Args(amountToWithdraw: amountToWithdraw,
                    amountToSpend: amountToSpend,
                    bankBaseUrl: bankBaseUrl,
                    bankAccessApiBaseUrl: bankAccessApiBaseUrl,
                    exchangeBaseUrl: exchangeBaseUrl,
                    merchantBaseUrl: merchantBaseUrl,
                    merchantAuthToken: merchantAuthToken
        )
    }

    let newVersion: Bool

    var amountToWithdraw: Amount
    var amountToSpend: Amount
    var bankBaseUrl: String
    var bankAccessApiBaseUrl: String
    var exchangeBaseUrl: String
    var merchantBaseUrl: String
    var merchantAuthToken: String

    struct Args: Encodable {
        var amountToWithdraw: Amount
        var amountToSpend: Amount
        var bankBaseUrl: String
        var bankAccessApiBaseUrl: String
        var exchangeBaseUrl: String
        var merchantBaseUrl: String
        var merchantAuthToken: String
    }
}
extension WalletModel {
    @MainActor func runIntegrationTestM(newVersion: Bool, test: Bool)
    async throws {               // M for MainActor
        let amountW = Amount(currency: test ? TESTCURRENCY : DEMOCURRENCY, integer: 3, fraction: 0)
        let amountS = Amount(currency: test ? TESTCURRENCY : DEMOCURRENCY, integer: 1, fraction: 0)
        let request = WalletBackendRunIntegration(newVersion: newVersion,
                                                  amountToWithdraw: amountW,
                                                  amountToSpend: amountS,
                                                  bankBaseUrl: (test ? TESTBANK : DEMOBANK) + APIBASEURL,
                                                  bankAccessApiBaseUrl: (test ? TESTBANK : DEMOBANK) + APIBASEURL,
                                                  exchangeBaseUrl: test ? TESTEXCHANGE : DEMOEXCHANGE,
                                                  merchantBaseUrl: test ? TESTBACKEND : DEMOBACKEND,
                                                  merchantAuthToken: MERCHANTAUTHTOKEN)
        let _ = try await sendRequest(request, ASYNCDELAY)
    }
} // runIntegrationTestM()
