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

/// Different types of transactions.
enum TransactionType: Codable {
    case withdrawal
    case payment
    case refund
    case tip
    case refresh
    
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        let str = try value.decode(String.self)
        let codingNames = [
            "TransactionWithdrawal" : TransactionType.withdrawal,
            "TransactionPayment" : TransactionType.payment,
            "TransactionRefund" : TransactionType.refund,
            "TransactionTip" : TransactionType.tip,
            "TransactionRefresh" : TransactionType.refresh
        ]
        if let type = codingNames[str] {
            self = type
        } else {
            throw TransactionTypeError.unknownTypeError
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
            case .withdrawal:
                try value.encode("TransactionWithdrawal")
            case .payment:
                try value.encode("TransactionPayment")
            case .refund:
                try value.encode("TransactionRefund")
            case .tip:
                try value.encode("TransactionTip")
            case .refresh:
                try value.encode("TransactionRefresh")
        }
    }
}

enum TransactionDecodingError: Error {
    case invalidStringValue
}

/// Details for a manual withdrawal.
struct ManualWithdrawalDetails: Codable {
    /// The payto URIs that the exchange supports.
    var exchangePaytoUris: [String]
    
    /// The public key of the newly created reserve.
    var reservePub: String
}

/// Details for a bank-integrated withdrawal.
struct BankIntegratedWithdrawalDetails: Codable {
    /// Whether the bank has confirmed the withdrawal.
    var confirmed: Bool

    /// The public key of the newly created reserve.
    var reservePub: String?

    /// URL for user-initiated confirmation
    var bankConfirmationUrl: String?
}

/// A withdrawal transaction.
struct TransactionWithdrawal: Decodable {
    enum WithdrawalDetails {
        case manual(ManualWithdrawalDetails)
        case bankIntegrated(BankIntegratedWithdrawalDetails)
    }
    
    /// The exchange that was withdrawn from.
    var exchangeBaseUrl: String
    
    /// The amount of the withdrawal, including fees.
    var amountRaw: Amount
    
    /// The amount that will be added to the withdrawer's account.
    var amountEffective: Amount
    
    /// The details of the withdrawal.
    var withdrawalDetails: WithdrawalDetails
    
    init(from decoder: Decoder) throws {
        enum CodingKeys: String, CodingKey {
            case exchangeBaseUrl
            case amountRaw
            case amountEffective
            case withdrawalDetails
            case type
            case exchangePaytoUris
            case reservePub
            case confirmed
            case bankConfirmationUrl
        }
        
        let value = try decoder.container(keyedBy: CodingKeys.self)
        self.exchangeBaseUrl = try value.decode(String.self, forKey: .exchangeBaseUrl)
        self.amountRaw = try value.decode(Amount.self, forKey: .amountRaw)
        self.amountEffective = try value.decode(Amount.self, forKey: .amountEffective)
        
        let detail = try value.nestedContainer(keyedBy: CodingKeys.self, forKey: .withdrawalDetails)
        let detailType = try detail.decode(String.self, forKey: .type)
        if detailType == "manual-transfer" {
            let paytoUris = try detail.decode([String].self, forKey: .exchangePaytoUris)
            let reservePub = try detail.decode(String.self, forKey: .reservePub)
            let manual = ManualWithdrawalDetails(exchangePaytoUris: paytoUris, reservePub: reservePub)
            self.withdrawalDetails = .manual(manual)
        } else if detailType == "taler-bank-integration-api" {
            let confirmed = try detail.decode(Bool.self, forKey: .confirmed)
            var bankConfirmationUrl: String? = nil
            if detail.contains(.bankConfirmationUrl) {
                bankConfirmationUrl = try detail.decode(String.self, forKey: .bankConfirmationUrl)
            }
            var reservePub : String? = nil
            if detail.contains(.reservePub) {
                reservePub = try detail.decode(String.self, forKey: .reservePub)
            }
            let bankDetails = BankIntegratedWithdrawalDetails(confirmed: confirmed, reservePub: reservePub,
                                                              bankConfirmationUrl: bankConfirmationUrl)
            self.withdrawalDetails = .bankIntegrated(bankDetails)
        } else {
            throw TransactionDecodingError.invalidStringValue
        }
    }
}
#if DEBUG
extension TransactionWithdrawal {       // for PreViews
    init(url: String) {
        self.exchangeBaseUrl = url
        self.amountRaw = try! Amount(fromString: "Taler:5")
        self.amountEffective = try! Amount(fromString: "Taler:4.8")
        let bankDetails = BankIntegratedWithdrawalDetails(confirmed: true, reservePub: nil,
                                                          bankConfirmationUrl: nil)
        self.withdrawalDetails = .bankIntegrated(bankDetails)
    }
}
#endif

/// A payment transaction.
struct TransactionPayment: Codable {
    /// Additional information about the payment.
    // TODO
    
    /// An identifier for the payment.
    var proposalId: String
    
    /// The current status of the payment.
    // TODO
    
    /// The amount that must be paid.
    var amountRaw: Amount
    
    /// The amount that was paid.
    var amountEffective: Amount
}

/// A refund transaction.
struct TransactionRefund: Codable {
    /// Identifier for the refund.
    var refundedTransactionId: String
    
    /// Additional information about the refund
    // TODO
    
    /// The amount that couldn't be applied because refund permissions expired.
    var amountInvalid: Amount
    
    /// The amount refunded by the merchant.
    var amountRaw: Amount
    
    /// The amount paid to the wallet after fees.
    var amountEffective: Amount
}

/// A tip transaction.
struct TransactionTip: Codable {
    /// The current status of the tip.
    // TODO
    
    /// The exchange that the tip will be withdrawn from
    var exchangeBaseUrl: String
    
    /// More information about the merchant sending the tip.
    // TODO
    
    /// The raw amount of the tip without fees.
    var amountRaw: Amount
    
    /// The amount added to the recipient's wallet.
    var amountEffective: Amount
}

/// A refresh transaction.
struct TransactionRefresh: Codable {
    /// The exchange that the coins are refreshed with.
    var exchangeBaseUrl: String
    
    /// The raw amount to refresh.
    var amountRaw: Amount
    
    /// The amount to be paid as fees for the refresh.
    var amountEffective: Amount
}

/// A wallet transaction.
struct Transaction: Decodable, Hashable {
//    private let symLog = SymLogC(0)

    var type: String
    var amountRaw: Amount
    var amountEffective: Amount
    var transactionId: String
    var timestamp: Timestamp
    var extendedStatus: String
    var pending: Bool
    var frozen: Bool

    var error: AnyCodable?
    var exchangeBaseUrl: String?



//    enum TransactionDetail {
//        case withdrawal(TransactionWithdrawal)
//    }
    
//    var detail: TransactionDetail
    
//    init(from decoder: Decoder) throws {
//        enum CodingKeys: String, CodingKey {
//            case transactionId
//            case timestamp
//            case pending
//            case error
//            case amountRaw
//            case amountEffective
//            case type
//        }
//
//        let value = try decoder.container(keyedBy: CodingKeys.self)
//        self.transactionId = try value.decode(String.self, forKey: .transactionId)
//        self.timestamp = try value.decode(Timestamp.self, forKey: .timestamp)
//        self.pending = try value.decode(Bool.self, forKey: .pending)
//        if value.contains(.error) {
//            self.error = try value.decode(AnyCodable.self, forKey: .error)
//        }
//        self.amountRaw = try value.decode(Amount.self, forKey: .amountRaw)
//        self.amountEffective = try value.decode(Amount.self, forKey: .amountEffective)
//
//        let type = try value.decode(String.self, forKey: .type)
//        if type == "withdrawal" {
//            let withdrawDetail = try TransactionWithdrawal.init(from: decoder)
//            self.detail = .withdrawal(withdrawDetail)
//        } else {
//            throw TransactionDecodingError.invalidStringValue
//        }
//        symLog.log("\(self)")
//    }
    
    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.transactionId == rhs.transactionId
    }
    
    func hash(into hasher: inout Hasher) {
        transactionId.hash(into: &hasher)
    }
}

#if DEBUG
extension Transaction {             // for PreViews
    init(id: String, time: Timestamp) {
        self.type = "withdrawal"
        self.amountRaw = try! Amount(fromString: "Taler:5")
        self.amountEffective = try! Amount(fromString: "Taler:4.8")
        self.transactionId = id
        self.timestamp = time
        self.extendedStatus = "done"
        self.pending = false
        self.frozen = false
        self.error = nil
        self.exchangeBaseUrl = "Exchange.Demo.Taler.net"
//        let withdrawDetail = TransactionWithdrawal(url: "Exchange.Demo.Taler.net")
//        self.detail = .withdrawal(withdrawDetail)
    }
}
#endif
