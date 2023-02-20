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
import AnyCodable
import taler_swift
import SymLog

enum TransactionTypeError: Error {
    case unknownTypeError
}

enum TransactionDecodingError: Error {
    case invalidStringValue
}

struct TransactionCommon: Decodable {
    var type: String
    var amountEffective: Amount
    var amountRaw: Amount
    var transactionId: String
    var timestamp: Timestamp
    var extendedStatus: String      // TODO: enum with some fixed values?
    var pending: Bool
    var frozen: Bool
}

struct WithdrawalDetails: Decodable {
    enum WithdrawalType: String, Decodable {
        case manual = "manual-transfer"
        case bankIntegrated = "taler-bank-integration-api"
        case peerPullCredit = "peer-pull-credit"
        case peerPushCredit = "peer-push-credit"
    }
    var type: WithdrawalType
    /// The public key of the reserve.
    var reservePub: String

  /// Details for manual withdrawals:
    /// The payto URIs that the exchange supports.
    var exchangePaytoUris: [String]?

  /// Details for bank-integrated withdrawals:
    /// Whether the bank has confirmed the withdrawal.
    var confirmed: Bool?
    /// URL for user-initiated confirmation
    var bankConfirmationUrl: String?
}

struct WithdrawalTransactionDetails: Decodable {
    var exchangeBaseUrl: String
    var withdrawalDetails: WithdrawalDetails
}

struct WithdrawalTransaction {
    var common: TransactionCommon
    var details: WithdrawalTransactionDetails
}

struct PaymentTransactionDetails: Decodable {
    var proposalId: String
    var status: String          // "paid"
    var totalRefundRaw: Amount
    var totalRefundEffective: Amount
    var refundPending: Amount?
//    var refunds: []
    var info: OrderShortInfo
}

struct PaymentTransaction {
    var common: TransactionCommon
    var details: PaymentTransactionDetails
}

struct RefundTransactionDetails: Decodable {
    var refundedTransactionId: String
    var refundPending: Amount?
    /// The amount that couldn't be applied because refund permissions expired.
    var amountInvalid: Amount?
    var info: OrderShortInfo
}

struct RefundTransaction {
    var common: TransactionCommon
    var details: RefundTransactionDetails
}

struct TipTransactionDetails: Decodable {
    /// The exchange that the tip will be withdrawn from
    var exchangeBaseUrl: String
}

struct TipTransaction {
    var common: TransactionCommon
    var details: TipTransactionDetails
}

struct RefreshTransactionDetails: Decodable {
    /// The exchange that the coins are refreshed with.
    var exchangeBaseUrl: String
}

struct RefreshTransaction {
    var common: TransactionCommon
    var details: RefreshTransactionDetails
}

enum Transaction: Decodable, Hashable, Identifiable {
    case withdrawal (WithdrawalTransaction)
    case payment (PaymentTransaction)
    case refund (RefundTransaction)
    case tip (TipTransaction)
    case refresh (RefreshTransaction)

    init(from decoder: Decoder) throws {
        let common = try TransactionCommon.init(from: decoder)

        switch (common.type) {
            case WITHDRAWAL:
                let details = try WithdrawalTransactionDetails.init(from: decoder)
                self = .withdrawal(WithdrawalTransaction(common: common, details: details))
            case PAYMENT:
                let details = try PaymentTransactionDetails.init(from: decoder)
                self = .payment(PaymentTransaction(common: common, details: details))
            case REFUND:
                let details = try RefundTransactionDetails.init(from: decoder)
                self = .refund(RefundTransaction(common: common, details: details))
            case TIP:
                let details = try TipTransactionDetails.init(from: decoder)
                self = .tip(TipTransaction(common: common, details: details))
            case REFRESH:
                let details = try RefreshTransactionDetails.init(from: decoder)
                self = .refresh(RefreshTransaction(common: common, details: details))
            default:
                let context = DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid transaction type")
                throw DecodingError.typeMismatch(Transaction.self, context)
        }
    }

    var id: String { common().transactionId }

    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }

    func common() -> TransactionCommon {
        switch self {
            case .withdrawal(let withdrawalTransaction):
                return withdrawalTransaction.common
            case .payment(let paymentTransaction):
                return paymentTransaction.common
            case .refund(let refundTransaction):
                return refundTransaction.common
            case .tip(let tipTransaction):
                return tipTransaction.common
            case .refresh(let refreshTransaction):
                return refreshTransaction.common
        }
    }

    func detailsToShow() -> Dictionary<String, String> {
        var result: [String:String] = [:]
        switch self {
            case .withdrawal(let withdrawalTransaction):
                result[EXCHANGEBASEURL] = withdrawalTransaction.details.exchangeBaseUrl
            case .payment(let paymentTransaction):
                result["status"] = paymentTransaction.details.status
            case .refund(let refundTransaction):
                result["summary"] = refundTransaction.details.info.summary
            case .tip(let tipTransaction):
                result[EXCHANGEBASEURL] = tipTransaction.details.exchangeBaseUrl
            case .refresh(let refreshTransaction):
                result[EXCHANGEBASEURL] = refreshTransaction.details.exchangeBaseUrl
        }
        return result
    }
}


#if DEBUG
extension Transaction {             // for PreViews
    init(id: String, time: Timestamp) {
        let common = TransactionCommon(type: WITHDRAWAL,
                            amountEffective: try! Amount(fromString: "Taler:4.8"),
                                  amountRaw: try! Amount(fromString: "Taler:5"),
                              transactionId: id, timestamp: time,
                             extendedStatus: "done", pending: false, frozen: false)
        let withdrawalDetails = WithdrawalDetails(type: WithdrawalDetails.WithdrawalType.bankIntegrated,
                                            reservePub: "Public Key of the Exchange",
                                             confirmed: true)
        let details = WithdrawalTransactionDetails(exchangeBaseUrl: "Exchange.Demo.Taler.net",
                                                   withdrawalDetails: withdrawalDetails)
        self = .withdrawal(WithdrawalTransaction(common: common, details: details))
    }
}
#endif
