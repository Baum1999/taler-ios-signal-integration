/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
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
                   corebankApiBaseUrl: bankBaseUrl,
                      exchangeBaseUrl: exchangeBaseUrl)
                        }

    var amount: Amount
    var bankBaseUrl: String
    var exchangeBaseUrl: String

    struct Args: Encodable {
        var amount: Amount
//        var bankBaseUrl: String                         // <= this should be the correct parameter name
        var corebankApiBaseUrl: String                // <= but this is used by wallet-core
        var exchangeBaseUrl: String
    }
}
extension WalletModel {
    @MainActor func loadTestKudosM(_ test: Int, amount: Amount, viewHandles: Bool = false)
    async throws {          // M for MainActor
        let request = WithdrawTestBalanceRequest(amount: amount,
                                            bankBaseUrl: test == 2 ? HEADBANK
                                                       : test == 1 ? TESTBANK : DEMOBANK,
                                        exchangeBaseUrl: test == 2 ? HEADEXCHANGE
                                                       : test == 1 ? TESTEXCHANGE : DEMOEXCHANGE)
        let response = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
    }
} // loadTestKudosM()
// MARK: -
/// A request to add a test balance to the wallet.
fileprivate struct RunIntegrationTest: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { newVersion ? "runIntegrationTestV2" : "runIntegrationTest" }
    func args() -> Args { Args(exchangeBaseUrl: exchangeBaseUrl,
                            corebankApiBaseUrl: bankBaseUrl,
                               merchantBaseUrl: merchantBaseUrl,
                             merchantAuthToken: merchantAuthToken,
                              amountToWithdraw: amountToWithdraw,
                                 amountToSpend: amountToSpend)
                        }

    let newVersion: Bool

    var exchangeBaseUrl: String
    var bankBaseUrl: String
    var merchantBaseUrl: String
    var merchantAuthToken: String
    var amountToWithdraw: Amount
    var amountToSpend: Amount

    struct Args: Encodable {
        var exchangeBaseUrl: String
//        var bankBaseUrl: String                         // <= this should be the correct parameter name
        var corebankApiBaseUrl: String                // <= but this is used by wallet-core
        var merchantBaseUrl: String
        var merchantAuthToken: String
        var amountToWithdraw: Amount
        var amountToSpend: Amount
    }
}
extension WalletModel {
    @MainActor func runIntegrationTestM(newVersion: Bool, test: Bool, viewHandles: Bool = false)
    async throws {               // M for MainActor
        let amountW = Amount(currency: test ? TESTCURRENCY : DEMOCURRENCY, cent: 300)
        let amountS = Amount(currency: test ? TESTCURRENCY : DEMOCURRENCY, cent: 100)
        let request = RunIntegrationTest(newVersion: newVersion,
                                    exchangeBaseUrl: test ? TESTEXCHANGE : DEMOEXCHANGE,
                                        bankBaseUrl: (test ? TESTBANK : DEMOBANK),
                                    merchantBaseUrl: test ? TESTBACKEND : DEMOBACKEND,
                                  merchantAuthToken: MERCHANTAUTHTOKEN,
                                   amountToWithdraw: amountW,
                                      amountToSpend: amountS)
        let _ = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
    }
} // runIntegrationTestM()
  // MARK: -
/// A request to add a test balance to the wallet.
fileprivate struct InfiniteTransactionLoop: WalletBackendFormattedRequest {
    struct Response: Decodable {}   // no result - getting no error back means success
    func operation() -> String { "testingInfiniteTransactionLoop" }
    func args() -> Args { Args(delayMs: delayMs,
                               shouldFetch: shouldFetch)
    }

    let delayMs: Int32
    let shouldFetch: Bool


    struct Args: Encodable {
        let delayMs: Int32
        let shouldFetch: Bool
    }
}
extension WalletModel {
    func testingInfiniteTransaction(delayMs: Int32, shouldFetch: Bool, viewHandles: Bool = false)
      async throws {
        let request = InfiniteTransactionLoop(delayMs: delayMs, shouldFetch: shouldFetch)
        let _ = try await sendRequest(request, ASYNCDELAY, viewHandles: viewHandles)
    }
} // runIntegrationTestM()
