/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
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

enum TransactionMinorState: String, Codable {
      // Placeholder until D37 is fully implemented
    case unknown
    case deposit
    case kyc        // KycRequired
    case aml        // AmlRequired
    case mergeKycRequired = "merge-kyc"
    case track
    case pay
    case rebindSession = "rebind-session"
    case refresh
    case pickup
    case autoRefund = "auto-refund"
    case user
    case bank
    case exchange
    case claimProposal = "claim-proposal"
    case checkRefund = "check-refund"
    case createPurse = "create-purse"
    case deletePurse = "delete-purse"
    case ready
    case merge
    case repurchase
    case bankRegisterReserve = "bank-register-reserve"
    case bankConfirmTransfer = "bank-confirm-transfer"
    case withdrawCoins = "withdraw-coins"
    case exchangeWaitReserve = "exchange-wait-reserve"
    case abortingBank = "aborting-bank"
    case refused
    case withdraw
    case merchantOrderProposed = "merchant-order-proposed"
    case proposed
    case refundAvailable = "refund-available"
    case acceptRefund = "accept-refund"

    case submitPayment = "submit-payment"
}

enum TransactionMajorState: String, Codable {
      // No state, only used when reporting transitions into the initial state
    case none
    case pending
    case done
    case aborting
    case aborted
    case suspended
    case dialog
    case suspendedAborting = "suspended-aborting"
    case failed
    case expired
      // Only used for the notification, never in the transaction history
    case deleted
      // Placeholder until D37 is fully implemented
    case unknown
}

struct TransactionState: Codable, Hashable {
    var major: TransactionMajorState
    var minor: TransactionMinorState?
}

struct TransactionTransition: Codable {             // Notification
    enum TransitionType: String, Codable {
        case transition = "transaction-state-transition"
    }
    var type: TransitionType
    var oldTxState: TransactionState
    var newTxState: TransactionState
    var transactionId: String
}

enum TxAction: String, Codable {
    case abort      // pending,dialog,suspended -> aborting
//  case revive     // aborting -> pending ?? maybe post 1.0
    case fail       // aborting -> failed
    case delete     // dialog,done,expired,aborted,failed -> ()
    case suspend    // pending -> suspended; aborting -> ab_suspended
    case resume     // suspended -> pending; ab_suspended -> aborting
}

struct TransactionCommon: Decodable {
    enum TransactionType: String, Codable {
        case withdrawal
        case deposit
        case payment
        case refund
        case refresh
        case reward
//        case tip
        case peerPushDebit = "peer-push-debit"              // send coins to peer, show QR
        case scanPushCredit = "peer-push-credit"            // scan QR, receive coins from peer
        case peerPullCredit = "peer-pull-credit"            // request payment from peer, show QR
        case scanPullDebit = "peer-pull-debit"              // scan QR, pay requested
    }
    var type: TransactionType
    var txState: TransactionState
    var amountEffective: Amount
    var amountRaw: Amount
    var transactionId: String
    var timestamp: Timestamp
    var txActions: [TxAction]

    func fee() -> Amount {
        do {
            return try Amount.diff(amountRaw, amountEffective)
        } catch {}
        do {
            return try Amount.diff(amountEffective, amountRaw)
        } catch {}
        return Amount(currency: amountRaw.currencyStr, integer: 0, fraction: 0)
    }

    func incoming() -> Bool {
        return type == .withdrawal
            || type == .refund
            || type == .reward
            || type == .peerPullCredit
            || type == .scanPushCredit
    }
}

struct WithdrawalDetails: Decodable {
    enum WithdrawalType: String, Decodable {
        case manual = "manual-transfer"
        case bankIntegrated = "taler-bank-integration-api"
    }
    var type: WithdrawalType
    /// The public key of the reserve.
    var reservePub: String
    var reserveIsReady: Bool

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
    var totalRefundRaw: Amount
    var totalRefundEffective: Amount
    var refundPending: Amount?
    var refundQueryActive: Bool?
    var refunds: [String]?           // TODO: array type?
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
    var info: OrderShortInfo?       // TODO: is this still here?
}

struct RefundTransaction {
    var common: TransactionCommon
    var details: RefundTransactionDetails
}

struct RewardTransactionDetails: Decodable {
    /// The exchange that the reward will be withdrawn from
    var exchangeBaseUrl: String
}

struct RewardTransaction {
    var common: TransactionCommon
    var details: RewardTransactionDetails
}

//struct TipTransactionDetails: Decodable {
//    /// The exchange that the tip will be withdrawn from
//    var exchangeBaseUrl: String
//}

//struct TipTransaction {
//    var common: TransactionCommon
//    var details: TipTransactionDetails
//}

enum RefreshReason: String, Decodable {
    case manual
    case payMerchant = "pay-merchant"
    case payDeposit = "pay-deposit"
    case payPeerPush = "pay-peer-push"
    case payPeerPull = "pay-peer-pull"
    case refund
    case abortPay = "abort-pay"
    case abortDeposit = "abort-deposit"
    case recoup
    case backupRestored = "backup-restored"
    case scheduled
}
struct RefreshTransactionDetails: Decodable {
    var refreshReason: RefreshReason
    var originatingTransactionId: String?
    var refreshInputAmount: Amount
    var refreshOutputAmount: Amount
}

struct RefreshTransaction {
    var common: TransactionCommon
    var details: RefreshTransactionDetails
}

struct P2pShortInfo: Codable {
    var summary: String
    var expiration: Timestamp
}

struct P2PTransactionDetails: Codable {
    var exchangeBaseUrl: String
    var talerUri: String?       // only if we initiated the transaction
    var info: P2pShortInfo
}

struct P2PTransaction {
    var common: TransactionCommon
    var details: P2PTransactionDetails
}

enum Transaction: Decodable, Hashable, Identifiable {
    case withdrawal (WithdrawalTransaction)
    case payment (PaymentTransaction)
    case refund (RefundTransaction)
    case reward (RewardTransaction)
//    case tip (TipTransaction)
    case refresh (RefreshTransaction)
    case peer2peer (P2PTransaction)

    init(from decoder: Decoder) throws {
        do {
            let common = try TransactionCommon.init(from: decoder)

            switch (common.type) {
                case .withdrawal:
                    let details = try WithdrawalTransactionDetails.init(from: decoder)
                    self = .withdrawal(WithdrawalTransaction(common: common, details: details))
                case .payment:
                    let details = try PaymentTransactionDetails.init(from: decoder)
                    self = .payment(PaymentTransaction(common: common, details: details))
                case .refund:
                    let details = try RefundTransactionDetails.init(from: decoder)
                    self = .refund(RefundTransaction(common: common, details: details))
                case .reward:
                    let details = try RewardTransactionDetails.init(from: decoder)
                    self = .reward(RewardTransaction(common: common, details: details))
//                case .tip:
//                    let details = try TipTransactionDetails.init(from: decoder)
//                    self = .tip(TipTransaction(common: common, details: details))
                case .refresh:
                    let details = try RefreshTransactionDetails.init(from: decoder)
                    self = .refresh(RefreshTransaction(common: common, details: details))
                case .peerPushDebit, .peerPullCredit, .scanPullDebit, .scanPushCredit:
                    let details = try P2PTransactionDetails.init(from: decoder)
                    self = .peer2peer(P2PTransaction(common: common, details: details))
                default:
                    let context = DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Invalid transaction type")
                    throw DecodingError.typeMismatch(Transaction.self, context)
            }
            return
        } catch DecodingError.dataCorrupted(let context) {
            print(context)
            throw TransactionDecodingError.invalidStringValue
        } catch DecodingError.keyNotFound(let key, let context) {
            print("Key '\(key)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
            throw TransactionDecodingError.invalidStringValue
        } catch DecodingError.valueNotFound(let value, let context) {
            print("Value '\(value)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
            throw TransactionDecodingError.invalidStringValue
        } catch DecodingError.typeMismatch(let type, let context) {
            print("Type '\(type)' mismatch:", context.debugDescription)
            print("codingPath:", context.codingPath)
            throw TransactionDecodingError.invalidStringValue
        } catch {       // TODO: native logging
            print("error: ", error)
            throw error
        }
    }

    var id: String { common.transactionId }

    var localizedType: String {
        switch common.type {
            case .withdrawal:   return String(localized: "Withdrawal")
            case .deposit:      return String(localized: "Deposit")
            case .payment:      return String(localized: "Payment")
            case .refund:       return String(localized: "Refund")
            case .refresh:      return String(localized: "Refresh")
            case .reward:       return String(localized: "Reward")
            case .peerPushDebit:  return String(localized: "P2P Send")
            case .scanPushCredit: return String(localized: "P2P Receive")
            case .peerPullCredit: return String(localized: "P2P Invoice")
            case .scanPullDebit:  return String(localized: "P2P Payment")
        }
    }
    
    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(common.txState)        // let SwiftUI redraw if txState changes
    }

    var isWithdrawal : Bool { common.type == .withdrawal }
    var isDeposit    : Bool { common.type == .deposit }
    var isPayment    : Bool { common.type == .payment }
    var isRefund     : Bool { common.type == .refund }
    var isRefresh    : Bool { common.type == .refresh }
    var isReward     : Bool { common.type == .reward }
//    var isTipPayment : Bool { common.type == .tip }
    var isSendCoins  : Bool { common.type == .peerPushDebit }
    var isRcvCoins   : Bool { common.type == .scanPushCredit }
    var isSendInvoice: Bool { common.type == .peerPullCredit }
    var isPayInvoice : Bool { common.type == .scanPullDebit }

    var isP2pOutgoing: Bool { isSendCoins || isPayInvoice}
    var isP2pIncoming: Bool { isSendInvoice || isRcvCoins}

    var isDone       : Bool { common.txState.major == .done }
    var isPending    : Bool { common.txState.major == .pending }
    var isAborting   : Bool { common.txState.major == .aborting }
    var isAborted    : Bool { common.txState.major == .aborted }
    var isFailed     : Bool { common.txState.major == .failed }
    var isExpired    : Bool { common.txState.major == .expired }
    var isSpecial    : Bool { isPending || isAborting || isAborted || isFailed || isExpired }

    var isAbortable  : Bool { common.txActions.contains(.abort) }
    var isFailable   : Bool { common.txActions.contains(.fail) }
    var isDeleteable : Bool { common.txActions.contains(.delete) }
    var isResumable  : Bool { common.txActions.contains(.resume) }
    var isSuspendable: Bool { common.txActions.contains(.suspend) }

    var common: TransactionCommon {
        switch self {
            case .withdrawal(let withdrawalTransaction):
                return withdrawalTransaction.common
            case .payment(let paymentTransaction):
                return paymentTransaction.common
            case .refund(let refundTransaction):
                return refundTransaction.common
            case .reward(let rewardTransaction):
                return rewardTransaction.common
//            case .tip(let tipTransaction):
//                return tipTransaction.common
            case .refresh(let refreshTransaction):
                return refreshTransaction.common
            case .peer2peer(let p2pTransaction):
                return p2pTransaction.common
        }
    }

    func detailsToShow() -> Dictionary<String, String> {
        var result: [String:String] = [:]
        switch self {
            case .withdrawal(let withdrawalTransaction):
                result[EXCHANGEBASEURL] = withdrawalTransaction.details.exchangeBaseUrl
            case .payment(let paymentTransaction):
                result["summary"] = paymentTransaction.details.info.summary
            case .refund(let refundTransaction):
                if let info = refundTransaction.details.info {
                    result["summary"] = info.summary
                }
            case .reward(let rewardTransaction):
                result[EXCHANGEBASEURL] = rewardTransaction.details.exchangeBaseUrl
//            case .tip(let tipTransaction):
//                result[EXCHANGEBASEURL] = tipTransaction.details.exchangeBaseUrl
            case .refresh(let refreshTransaction):
                result["reason"] = refreshTransaction.details.refreshReason.rawValue
            case .peer2peer(let p2pTransaction):
                result[EXCHANGEBASEURL] = p2pTransaction.details.exchangeBaseUrl
                result["summary"] = p2pTransaction.details.info.summary
                result[TALERURI] = p2pTransaction.details.talerUri ?? ""
        }

        return result
    }
}
