/*
 * This file is part of GNU Taler
 * (C) 2026 Bohdan, Volodymyr Potuzhnyi
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING. If not, see <http://www.gnu.org/licenses/>
 */

import Foundation

struct Timestamp: Codable, Equatable {
    let seconds: UInt64

    var date: Date {
        Date(timeIntervalSince1970: Double(seconds))
    }

    init(seconds: UInt64) {
        self.seconds = seconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(UInt64.self, forKey: .tS) {
            self.seconds = value
        } else if let str = try? container.decode(String.self, forKey: .tS), str == "never" {
            self.seconds = UInt64.max
        } else {
            throw DecodingError.dataCorruptedError(forKey: .tS, in: container, debugDescription: "Expected integer or \"never\" for t_s")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if seconds == UInt64.max {
            try container.encode("never", forKey: .tS)
        } else {
            try container.encode(seconds, forKey: .tS)
        }
    }

    enum CodingKeys: String, CodingKey {
        case tS = "t_s"
    }
}

struct OrderHistoryEntry: Codable, Identifiable {
    let orderId: String
    let rowId: Int64?
    let timestamp: Timestamp
    let amount: Amount
    let summary: String
    let paid: Bool
    let refundable: Bool
    var refunded: Bool
    var refundAmount: Amount?
    var pendingRefundAmount: Amount?
    var refundPending: Bool

    var id: String { orderId }

    var hasRefund: Bool {
        refunded || (refundAmount?.isZero == false)
    }

    var hasPendingRefund: Bool {
        refundPending || (pendingRefundAmount?.isZero == false)
    }

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case rowId = "row_id"
        case timestamp
        case amount
        case summary
        case paid
        case refundable
        case refunded
        case refundAmount = "refund_amount"
        case refundedAmount = "refunded_amount"
        case pendingRefundAmount = "pending_refund_amount"
        case refundPendingAmount = "refund_pending_amount"
        case refundPending = "refund_pending"
    }

    init(
        orderId: String,
        rowId: Int64? = nil,
        timestamp: Timestamp,
        amount: Amount,
        summary: String,
        paid: Bool,
        refundable: Bool,
        refunded: Bool = false,
        refundAmount: Amount? = nil,
        pendingRefundAmount: Amount? = nil,
        refundPending: Bool = false
    ) {
        self.orderId = orderId
        self.rowId = rowId
        self.timestamp = timestamp
        self.amount = amount
        self.summary = summary
        self.paid = paid
        self.refundable = refundable
        self.refunded = refunded
        self.refundAmount = refundAmount
        self.pendingRefundAmount = pendingRefundAmount
        self.refundPending = refundPending
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = try container.decode(String.self, forKey: .orderId)
        rowId = try container.decodeIfPresent(Int64.self, forKey: .rowId)
        timestamp = try container.decode(Timestamp.self, forKey: .timestamp)
        amount = try container.decode(Amount.self, forKey: .amount)
        summary = try container.decode(String.self, forKey: .summary)
        paid = try container.decode(Bool.self, forKey: .paid)
        refundable = try container.decode(Bool.self, forKey: .refundable)
        refunded = try container.decodeIfPresent(Bool.self, forKey: .refunded) ?? false
        if let ra = try container.decodeIfPresent(Amount.self, forKey: .refundAmount) {
            refundAmount = ra
        } else {
            refundAmount = try container.decodeIfPresent(Amount.self, forKey: .refundedAmount)
        }
        if let pra = try container.decodeIfPresent(Amount.self, forKey: .pendingRefundAmount) {
            pendingRefundAmount = pra
        } else {
            pendingRefundAmount = try container.decodeIfPresent(Amount.self, forKey: .refundPendingAmount)
        }
        refundPending = try container.decodeIfPresent(Bool.self, forKey: .refundPending) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(orderId, forKey: .orderId)
        try container.encodeIfPresent(rowId, forKey: .rowId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(amount, forKey: .amount)
        try container.encode(summary, forKey: .summary)
        try container.encode(paid, forKey: .paid)
        try container.encode(refundable, forKey: .refundable)
        try container.encode(refunded, forKey: .refunded)
        try container.encodeIfPresent(refundAmount, forKey: .refundAmount)
        try container.encodeIfPresent(pendingRefundAmount, forKey: .pendingRefundAmount)
        try container.encode(refundPending, forKey: .refundPending)
    }
}

struct OrderHistory: Codable {
    let orders: [OrderHistoryEntry]
}
