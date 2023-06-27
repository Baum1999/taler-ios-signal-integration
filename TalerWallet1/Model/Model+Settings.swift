/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

fileprivate let DEMO_EXCHANGEBASEURL = DEMOEXCHANGE
fileprivate let DEMO_BANKBASEURL     = DEMOBANK
fileprivate let DEMO_BANKAPIBASEURL  = DEMOBANK + "/demobanks/default/access-api/"
fileprivate let DEMO_MERCHANTBASEURL = DEMOBACKEND
fileprivate let DEMO_MERCHANTAUTHTOKEN = "secret-token:sandbox"

// MARK: -
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
extension WalletModel {
    @MainActor func loadTestKudosM()
    async throws {          // M for MainActor
        let amount = Amount(currency: DEMOCURRENCY, integer: 11, fraction: 0)
        let request = WalletBackendWithdrawTestBalance(amount: amount,
                                                       bankBaseUrl: DEMO_BANKBASEURL,
                                                       exchangeBaseUrl: DEMO_EXCHANGEBASEURL,
                                                       bankAccessApiBaseUrl: DEMO_BANKAPIBASEURL)
        let response = try await sendRequest(request, ASYNCDELAY)
    }
} // loadTestKudosM()
// MARK: -
/// A request to add a test balance to the wallet.
fileprivate struct WalletBackendRunIntegration: WalletBackendFormattedRequest {
    struct Response: Decodable {}
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
    @MainActor func runIntegrationTestM(newVersion: Bool)
    async throws {               // M for MainActor
        let amountW = Amount(currency: DEMOCURRENCY, integer: 3, fraction: 0)
        let amountS = Amount(currency: DEMOCURRENCY, integer: 1, fraction: 0)
        let request = WalletBackendRunIntegration(newVersion: newVersion,
                                                  amountToWithdraw: amountW,
                                                  amountToSpend: amountS,
                                                  bankBaseUrl: DEMO_BANKAPIBASEURL,
                                                  bankAccessApiBaseUrl: DEMO_BANKAPIBASEURL,
                                                  exchangeBaseUrl: DEMO_EXCHANGEBASEURL,
                                                  merchantBaseUrl: DEMO_MERCHANTBASEURL,
                                                  merchantAuthToken: DEMO_MERCHANTAUTHTOKEN)
        let _ = try await sendRequest(request, ASYNCDELAY)
    }
} // runIntegrationTestM()
