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
import AnyCodable
//import SymLog
fileprivate let ASYNCDELAY: UInt = 0   //set e.g to 6 or 9 seconds for debugging

enum PaymentState {
    case error
    case waitingForUriDetails
    case receivedUriDetails
    case waitingForPaymentAck
    case receivedPaymentAck
}

class PaymentURIModel: WalletModel {
    @Published var paymentState: PaymentState?
}


// MARK: - ContractTerms
struct ContractTerms: Codable {
    let amount: Amount
    let maxFee: Amount
    let maxWireFee: Amount
    let merchant: Merchant
    let extra: Extra
    let summary: String
    let timestamp: Timestamp
    let payDeadline: Timestamp
    let refundDeadline: Timestamp
    let wireTransferDeadline: Timestamp
    let merchantBaseURL: String
    let fulfillmentURL: String
    let publicReorderURL: String
    let auditors: [Auditor]
    let exchanges: [ExchangeForPay]
    let orderID, nonce, merchantPub: String
    let products: [Product]
    let hWire: String
    let wireMethod: String
    let wireFeeAmortization: Int

    enum CodingKeys: String, CodingKey {
        case amount
        case maxFee = "max_fee"
        case maxWireFee = "max_wire_fee"
        case merchant, extra, summary
        case timestamp
        case payDeadline = "pay_deadline"
        case refundDeadline = "refund_deadline"
        case wireTransferDeadline = "wire_transfer_deadline"
        case merchantBaseURL = "merchant_base_url"
        case fulfillmentURL = "fulfillment_url"
        case publicReorderURL = "public_reorder_url"
        case auditors, exchanges
        case orderID = "order_id"
        case nonce
        case merchantPub = "merchant_pub"
        case products
        case hWire = "h_wire"
        case wireMethod = "wire_method"
        case wireFeeAmortization = "wire_fee_amortization"
    }
}

// MARK: - Auditor
struct Auditor: Codable {
    let name: String
    let auditorPub: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case name
        case auditorPub = "auditor_pub"
        case url
    }
}

// MARK: - Exchange
struct ExchangeForPay: Codable {
    let url: String
    let masterPub: String

    enum CodingKeys: String, CodingKey {
        case url
        case masterPub = "master_pub"
    }
}

// MARK: - Extra
struct Extra: Codable {
    let articleName: String

    enum CodingKeys: String, CodingKey {
        case articleName = "article_name"
    }
}

// MARK: -
/// The result from PreparePayForUri
struct PaymentDetailsForUri: Codable {
    let status: String
    let amountRaw: Amount
    let amountEffective: Amount
    let noncePriv: String
    let proposalId: String
    let contractTerms: ContractTerms
    let contractTermsHash: String
}
/// A request to get an exchange's payment contract terms.
fileprivate struct PreparePayForUri: WalletBackendFormattedRequest {
    typealias Response = PaymentDetailsForUri
    func operation() -> String { return "preparePayForUri" }
    func args() -> Args { return Args(talerPayUri: talerPayUri) }

    var talerPayUri: String
    struct Args: Encodable {
        var talerPayUri: String
    }
}
// MARK: -
/// The result from getPaymentDetailsForAmount
struct ConfirmPayResult: Decodable {
    var type: String
    var contractTerms: ContractTerms
    var transactionId: String
}
/// A request to get an exchange's payment details.
fileprivate struct confirmPayForUri: WalletBackendFormattedRequest {
    typealias Response = ConfirmPayResult
    func operation() -> String { return "confirmPay" }
    func args() -> Args { return Args(proposalId: proposalId) }

    var proposalId: String
    struct Args: Encodable {
        var proposalId: String
    }
}
// MARK: -
extension PaymentURIModel {
    /// load payment details. Networking involved
    @MainActor
    func preparePayForUri(_ talerPayUri: String) async throws -> PaymentDetailsForUri {
        do {
            paymentState = .waitingForUriDetails
            let request = PreparePayForUri(talerPayUri: talerPayUri)
            let response = try await sendRequest(request, ASYNCDELAY)
            paymentState = .receivedUriDetails
            return response
        } catch {
            paymentState = .error
            throw error
        }
    }
    @MainActor
    func confirmPay(_ proposalId: String) async throws -> ConfirmPayResult {
        do {
            paymentState = .waitingForPaymentAck
            let request = confirmPayForUri(proposalId: proposalId)
            let response = try await sendRequest(request, ASYNCDELAY)
            paymentState = .receivedPaymentAck
            return response
        } catch {
            paymentState = .error
            throw error
        }
    }
}
