/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift
import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

fileprivate let MERCHANTAUTHTOKEN = "secret-token:sandbox"

// MARK: -
/// A request to add a test balance to the wallet.
fileprivate struct WithdrawTestBalanceRequest: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "withdrawTestBalance" }
    func args() -> Args { Args(amount: amount,
//                        bankBaseUrl: bankBaseUrl,
                   corebankApiBaseUrl: corebankApiBaseUrl,
                      exchangeBaseUrl: exchangeBaseUrl)
                        }

    var amount: Amount
//    var bankBaseUrl: String
    var corebankApiBaseUrl: String
    var exchangeBaseUrl: String

    struct Args: Encodable {
        var amount: Amount
//        var bankBaseUrl: String                         // <= this should be the correct parameter name
        var corebankApiBaseUrl: String                // <= but currently this is used by wallet-core
        var exchangeBaseUrl: String
    }
}
extension WalletModel {
    @MainActor func loadTestKudosM(test: Bool)
    async throws {          // M for MainActor
        let amount = Amount(currency:  test ? TESTCURRENCY : DEMOCURRENCY, integer: 11, fraction: 0)
        let request = WithdrawTestBalanceRequest(amount: amount,
//                                                 bankBaseUrl: test ? TESTBANK : DEMOBANK,
                                                 corebankApiBaseUrl: test ? TESTBANK : DEMOBANK,
                                                 exchangeBaseUrl: test ? TESTEXCHANGE : DEMOEXCHANGE)
        let response = try await sendRequest(request, ASYNCDELAY)
    }
} // loadTestKudosM()
// MARK: -
/// A request to add a test balance to the wallet.
fileprivate struct RunIntegrationTest: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { newVersion ? "runIntegrationTestV2" : "runIntegrationTest" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl,
//                                 bankBaseUrl: bankBaseUrl,
                            corebankApiBaseUrl: corebankApiBaseUrl,
                               merchantBaseUrl: merchantBaseUrl,
                             merchantAuthToken: merchantAuthToken,
                              amountToWithdraw: amountToWithdraw,
                                 amountToSpend: amountToSpend)
                        }

    let newVersion: Bool

    var exchangeBaseUrl: String
//    var bankBaseUrl: String
    var corebankApiBaseUrl: String
    var merchantBaseUrl: String
    var merchantAuthToken: String
    var amountToWithdraw: Amount
    var amountToSpend: Amount

    struct Args: Encodable {
        var exchangeBaseUrl: String
//        var bankBaseUrl: String
        var corebankApiBaseUrl: String
        var merchantBaseUrl: String
        var merchantAuthToken: String
        var amountToWithdraw: Amount
        var amountToSpend: Amount
    }
}
extension WalletModel {
    @MainActor func runIntegrationTestM(newVersion: Bool, test: Bool)
    async throws {               // M for MainActor
        let amountW = Amount(currency: test ? TESTCURRENCY : DEMOCURRENCY, integer: 3, fraction: 0)
        let amountS = Amount(currency: test ? TESTCURRENCY : DEMOCURRENCY, integer: 1, fraction: 0)
        let request = RunIntegrationTest(newVersion: newVersion,
                                         exchangeBaseUrl: test ? TESTEXCHANGE : DEMOEXCHANGE,
//                                         bankBaseUrl: (test ? TESTBANK : DEMOBANK),
                                         corebankApiBaseUrl: (test ? TESTBANK : DEMOBANK),
                                         merchantBaseUrl: test ? TESTBACKEND : DEMOBACKEND,
                                         merchantAuthToken: MERCHANTAUTHTOKEN,
                                         amountToWithdraw: amountW,
                                         amountToSpend: amountS)
        let _ = try await sendRequest(request, ASYNCDELAY)
    }
} // runIntegrationTestM()
