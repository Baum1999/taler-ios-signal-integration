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

enum WithdrawState {
    case error
    case waitingForUriDetails
    case receivedUriDetails
    case waitingForAmountDetails
    case receivedAmountDetails
    case waitingForTOS
    case receivedTOS
    case waitingForTOSAck
    case receivedTOSAck
    case waitingForWithdrAck
    case receivedWithdrAck
}

class WithdrawURIModel: WalletModel {
    @Published var withdrawState: WithdrawState?
}

// MARK: -
/// The result from getWithdrawalDetailsForUri
struct WithdrawalDetailsForUri: Decodable {
    var amount: Amount
    var defaultExchangeBaseUrl: String?
    var possibleExchanges: [ExchangeListItem]
}
struct ExchangeListItem: Codable, Hashable {
    var exchangeBaseUrl: String
    var currency: String
    var paytoUris: [String]

    public static func == (lhs: ExchangeListItem, rhs: ExchangeListItem) -> Bool {
        return lhs.exchangeBaseUrl == rhs.exchangeBaseUrl &&
        lhs.currency == rhs.currency &&
        lhs.paytoUris == rhs.paytoUris
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(exchangeBaseUrl)
        hasher.combine(currency)
        hasher.combine(paytoUris)
    }
}
/// A request to get an exchange's withdrawal details.
fileprivate struct GetWithdrawalDetailsForURI: WalletBackendFormattedRequest {
    typealias Response = WithdrawalDetailsForUri
    func operation() -> String { return "getWithdrawalDetailsForUri" }
    func args() -> Args { return Args(talerWithdrawUri: talerWithdrawUri) }

    var talerWithdrawUri: String
    struct Args: Encodable {
        var talerWithdrawUri: String
    }
}
// MARK: -
/// The result from getWithdrawalDetailsForAmount
struct WithdrawalDetailsForAmount: Decodable {
    var tosAccepted: Bool
    var amountRaw: Amount
    var amountEffective: Amount
}
/// A request to get an exchange's withdrawal details.
fileprivate struct GetWithdrawalDetailsForAmount: WalletBackendFormattedRequest {
    typealias Response = WithdrawalDetailsForAmount
    func operation() -> String { return "getWithdrawalDetailsForAmount" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl, amount: amount) }

    var exchangeBaseUrl: String
    var amount: Amount
    struct Args: Encodable {
        var exchangeBaseUrl: String
        var amount: Amount
    }
}
// MARK: -
struct ExchangeTermsOfService: Decodable {
    var content: String
    var currentEtag: String
    var acceptedEtag: String?
}
/// A request to query an exchange's terms of service.
fileprivate struct GetExchangeTermsOfService: WalletBackendFormattedRequest {
    typealias Response = ExchangeTermsOfService
    func operation() -> String { return "getExchangeTos" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl) }

    var exchangeBaseUrl: String
    struct Args: Encodable {
        var exchangeBaseUrl: String
    }
}
// MARK: -
/// A request to mark an exchange's terms of service as accepted.
fileprivate struct SetExchangeTOSAccepted: WalletBackendFormattedRequest {
    struct Response: Decodable {}
    func operation() -> String { return "setExchangeTosAccepted" }
    func args() -> Args { return Args(exchangeBaseUrl: exchangeBaseUrl, etag: etag) }

    var exchangeBaseUrl: String
    var etag: String

    struct Args: Encodable {
        var exchangeBaseUrl: String
        var etag: String
    }
}
// MARK: -
struct BankConfirmation: Decodable {
    var bankConfirmationUrl: String?
}
/// A request to accept a bank-integrated withdrawl.
fileprivate struct AcceptBankIntegratedWithdrawal: WalletBackendFormattedRequest {
    typealias Response = BankConfirmation
    func operation() -> String { return "acceptBankIntegratedWithdrawal" }
    func args() -> Args { return Args(talerWithdrawUri: talerWithdrawUri, exchangeBaseUrl: exchangeBaseUrl) }

    var talerWithdrawUri: String
    var exchangeBaseUrl: String

    struct Args: Encodable {
        var talerWithdrawUri: String
        var exchangeBaseUrl: String
    }
}
// MARK: -
extension WithdrawURIModel {
    /// load withdrawal details. Networking involved
    @MainActor
    func loadWithdrawalDetailsForURI(_ talerWithdrawUri: String) async throws -> WithdrawalDetailsForUri {
        do {
            withdrawState = .waitingForUriDetails
            let request = GetWithdrawalDetailsForURI(talerWithdrawUri: talerWithdrawUri)
            let response = try await sendRequest(request, ASYNCDELAY)
            withdrawState = .receivedUriDetails
            return response
        } catch {
            withdrawState = .error
            throw error
        }
    }
    @MainActor
    func loadWithdrawalDetailsForAmount(_ detailsForUri: WithdrawalDetailsForUri) async throws -> WithdrawalDetailsForAmount {
        do {
            withdrawState = .waitingForAmountDetails
            let baseURL = detailsForUri.defaultExchangeBaseUrl!
            let request = GetWithdrawalDetailsForAmount(exchangeBaseUrl: baseURL, amount: detailsForUri.amount)
            let response = try await sendRequest(request, ASYNCDELAY)
            withdrawState = .receivedAmountDetails
            return response
        } catch {
            withdrawState = .error
            throw error
        }
    }
    @MainActor
    func loadExchangeTermsOfService(_ exchangeBaseUrl: String) async throws -> ExchangeTermsOfService {
        do {
            withdrawState = .waitingForTOS
            let request = GetExchangeTermsOfService(exchangeBaseUrl: exchangeBaseUrl)
            let response = try await sendRequest(request, ASYNCDELAY)
            withdrawState = .receivedTOS
            return response
        } catch {
            withdrawState = .error
            throw error
        }
    }
    @MainActor
    func setExchangeTOSAccepted(_ exchangeBaseUrl: String, etag: String) async throws -> Decodable {
        do {
            withdrawState = .waitingForTOSAck
            let request = SetExchangeTOSAccepted(exchangeBaseUrl: exchangeBaseUrl, etag: etag)
            let response = try await sendRequest(request, ASYNCDELAY)
            withdrawState = .receivedTOSAck
            return response
        } catch {
            withdrawState = .error
            throw error
        }
    }
    @MainActor
    func sendAcceptIntWithdrawal(_ exchangeBaseUrl: String, withdrawURL: String) async throws -> String? {
        do {
            withdrawState = .waitingForWithdrAck
            let request = AcceptBankIntegratedWithdrawal(talerWithdrawUri: withdrawURL, exchangeBaseUrl: exchangeBaseUrl)
            let response = try await sendRequest(request, ASYNCDELAY)
            withdrawState = .receivedWithdrAck
            return response.bankConfirmationUrl
        } catch {
            withdrawState = .error
            throw error
        }
    }
}
