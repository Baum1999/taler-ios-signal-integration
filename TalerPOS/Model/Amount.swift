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

enum AmountError: Error {
    case invalidCurrency
    case invalidFormat
    case overflow
    case underflow
    case currencyMismatch
}

struct Amount: Codable, Equatable, Hashable, Comparable {
    let currency: String
    let value: UInt64
    let fraction: UInt32

    static let fractionalBase: UInt32 = 100_000_000
    static let maxFractionalDigits = 8
    static let maxValue: UInt64 = (1 << 52)
    private static let currencyRegex = try! NSRegularExpression(pattern: "^[-_*A-Za-z0-9]{1,12}$")

    static func zero(_ currency: String) -> Amount {
        Amount(currency: currency, value: 0, fraction: 0)
    }

    var isZero: Bool {
        value == 0 && fraction == 0
    }

    init(currency: String, value: UInt64, fraction: UInt32 = 0) {
        self.currency = currency
        self.value = value
        self.fraction = fraction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        guard let parsed = Amount.parse(str) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid amount: \(str)")
        }
        self = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    static func isValidCurrency(_ currency: String) -> Bool {
        let range = NSRange(currency.startIndex..., in: currency)
        return currencyRegex.firstMatch(in: currency, range: range) != nil
    }

    static func parse(_ str: String) -> Amount? {
        let parts = str.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let currency = String(parts[0])
        guard isValidCurrency(currency) else { return nil }
        let valueParts = parts[1].split(separator: ".", maxSplits: 1)
        guard let value = UInt64(valueParts[0]) else { return nil }
        guard value <= maxValue else { return nil }
        var fraction: UInt32 = 0
        if valueParts.count == 2 {
            let fracStr = String(valueParts[1])
            guard fracStr.count <= maxFractionalDigits else { return nil }
            guard fracStr.allSatisfy(\.isNumber) else { return nil }
            var padded = fracStr
            while padded.count < 8 { padded += "0" }
            guard let f = UInt32(padded) else { return nil }
            fraction = f
        }
        return Amount(currency: currency, value: value, fraction: fraction)
    }

    static func fromString(_ currency: String, _ amountStr: String) -> Amount? {
        let trimmed = amountStr.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let valueParts = trimmed.split(separator: ".", maxSplits: 1)
        guard let intPart = UInt64(valueParts[0]) else { return nil }
        guard intPart <= maxValue else { return nil }
        var fraction: UInt32 = 0
        if valueParts.count == 2 {
            let fracStr = String(valueParts[1])
            guard fracStr.count <= maxFractionalDigits else { return nil }
            guard fracStr.allSatisfy(\.isNumber) else { return nil }
            var padded = fracStr
            while padded.count < 8 { padded += "0" }
            guard let f = UInt32(padded) else { return nil }
            fraction = f
        }
        return Amount(currency: currency, value: intPart, fraction: fraction)
    }

    func addInputDigit(_ digit: Int, numInputDigits: Int) -> Amount? {
        let digitCount = numInputDigits > 0 ? numInputDigits : 2
        let fracBase = Self.pow10(digitCount)
        let totalUnits = UInt64(value) * UInt64(fracBase) + UInt64(fraction) / (UInt64(Self.fractionalBase) / UInt64(fracBase))
        let shifted = totalUnits * 10 + UInt64(digit)
        let newValue = shifted / UInt64(fracBase)
        guard newValue <= Self.maxValue else { return nil }
        let newFracSmall = shifted % UInt64(fracBase)
        let newFraction = UInt32(newFracSmall) * (Self.fractionalBase / UInt32(fracBase))
        return Amount(currency: currency, value: newValue, fraction: newFraction)
    }

    // Integer-only keypad digit removal (no floating point)
    func removeInputDigit(numInputDigits: Int) -> Amount {
        let digitCount = numInputDigits > 0 ? numInputDigits : 2
        let fracBase = Self.pow10(digitCount)
        let totalUnits = UInt64(value) * UInt64(fracBase) + UInt64(fraction) / (UInt64(Self.fractionalBase) / UInt64(fracBase))
        let shifted = totalUnits / 10
        let newValue = shifted / UInt64(fracBase)
        let newFracSmall = shifted % UInt64(fracBase)
        let newFraction = UInt32(newFracSmall) * (Self.fractionalBase / UInt32(fracBase))
        return Amount(currency: currency, value: newValue, fraction: newFraction)
    }

    private static func pow10(_ n: Int) -> UInt32 {
        var result: UInt32 = 1
        for _ in 0..<n { result *= 10 }
        return result
    }

    static func + (lhs: Amount, rhs: Amount) -> Amount {
        precondition(lhs.currency == rhs.currency, "Currency mismatch: \(lhs.currency) vs \(rhs.currency)")
        var fraction = UInt64(lhs.fraction) + UInt64(rhs.fraction)
        var value = lhs.value + rhs.value
        if fraction >= UInt64(fractionalBase) {
            value += 1
            fraction -= UInt64(fractionalBase)
        }
        precondition(value <= maxValue, "Amount overflow")
        return Amount(currency: lhs.currency, value: value, fraction: UInt32(fraction))
    }

    static func - (lhs: Amount, rhs: Amount) -> Amount {
        precondition(lhs.currency == rhs.currency, "Currency mismatch: \(lhs.currency) vs \(rhs.currency)")
        var fraction = Int64(lhs.fraction) - Int64(rhs.fraction)
        var value = Int64(lhs.value) - Int64(rhs.value)
        if fraction < 0 {
            value -= 1
            fraction += Int64(fractionalBase)
        }
        precondition(value >= 0, "Amount underflow")
        return Amount(currency: lhs.currency, value: UInt64(value), fraction: UInt32(fraction))
    }

    static func * (lhs: Amount, rhs: Int) -> Amount {
        var result = Amount.zero(lhs.currency)
        for _ in 0..<rhs {
            result = result + lhs
        }
        return result
    }

    static func < (lhs: Amount, rhs: Amount) -> Bool {
        precondition(lhs.currency == rhs.currency, "Currency mismatch: \(lhs.currency) vs \(rhs.currency)")
        if lhs.value != rhs.value { return lhs.value < rhs.value }
        return lhs.fraction < rhs.fraction
    }

    static func > (lhs: Amount, rhs: Amount) -> Bool {
        precondition(lhs.currency == rhs.currency, "Currency mismatch: \(lhs.currency) vs \(rhs.currency)")
        if lhs.value != rhs.value { return lhs.value > rhs.value }
        return lhs.fraction > rhs.fraction
    }
}

extension Amount: CustomStringConvertible {
    var description: String {
        let fracStr = String(format: "%08u", fraction)
        let trimmed = fracStr.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        if trimmed.isEmpty {
            return "\(currency):\(value)"
        }
        return "\(currency):\(value).\(trimmed)"
    }

    var readableAmount: String {
        readableAmount(numDigits: 2)
    }

    func readableAmount(numDigits: Int) -> String {
        let digits = max(numDigits, 0)
        if digits == 0 { return "\(value) \(currency)" }
        let fracStr = String(format: "%08u", fraction)
        let trimmed = String(fracStr.prefix(digits))
        return "\(value).\(trimmed) \(currency)"
    }

    func readableAmount(spec: CurrencySpecification?) -> String {
        guard let spec else { return readableAmount(numDigits: 2) }
        let maxDigits = spec.displayDigits
        let minDigits = spec.trailingZeroDigits

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minDigits
        formatter.maximumFractionDigits = max(maxDigits, minDigits)
        formatter.usesGroupingSeparator = true

        let decimalValue = Decimal(value) + Decimal(fraction) / Decimal(Amount.fractionalBase)
        let formatted = formatter.string(from: decimalValue as NSDecimalNumber) ?? "\(value)"

        if let symbol = spec.symbol {
            return "\(symbol)\u{00A0}\(formatted)"
        }
        return "\(formatted) \(currency)"
    }

    func amountStr(numDigits: Int = 2) -> String {
        let digits = max(numDigits, 0)
        if digits == 0 { return "\(value)" }
        let fracStr = String(format: "%08u", fraction)
        let trimmed = String(fracStr.prefix(digits))
        return "\(value).\(trimmed)"
    }
}
