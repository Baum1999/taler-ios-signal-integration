/*
 * This file is part of GNU Taler
 * (C) 2021 Taler Systems S.A.
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

enum AmountError: Error {
    case invalidStringRepresentation
    case incompatibleCurrency
    case invalidAmount
    case negativeAmount
}

class Amount: Codable, CustomStringConvertible {
    private static let maxValue: UInt64 = 1 << 52
    private static let fractionalBase: UInt32 = 100000000
    private static let fractionalBaseDigits: UInt = 8
    var currency: String
    var value: UInt64
    var fraction: UInt32
    var description: String {
        if fraction == 0 {
            return "\(currency):\(value)"
        } else {
            var frac = fraction
            var fracStr = ""
            while (frac > 0) {
                fracStr += "\(frac / (Amount.fractionalBase / 10))"
                frac = (frac * 10) % Amount.fractionalBase
            }
            return "\(currency):\(value).\(fracStr)"
        }
    }
    var valid: Bool {
        return (value <= Amount.maxValue && currency != "")
    }
    
    init(fromString string: String) throws {
        guard let separatorIndex = string.firstIndex(of: ":") else { throw AmountError.invalidStringRepresentation }
        self.currency = String(string[..<separatorIndex])
        let amountStr = String(string[string.index(separatorIndex, offsetBy: 1)...])
        if let dotIndex = amountStr.firstIndex(of: ".") {
            let valueStr = String(amountStr[..<dotIndex])
            let fractionStr = String(amountStr[string.index(dotIndex, offsetBy: 1)...])
            guard let _value = UInt64(valueStr) else { throw AmountError.invalidStringRepresentation }
            self.value = _value
            self.fraction = 0
            var digitValue = Amount.fractionalBase / 10
            for char in fractionStr {
                guard let digit = char.wholeNumberValue else { throw AmountError.invalidStringRepresentation }
                self.fraction += digitValue * UInt32(digit)
                digitValue /= 10
            }
        } else {
            guard let _value = UInt64(amountStr) else { throw AmountError.invalidStringRepresentation }
            self.value = _value
            self.fraction = 0
        }
        guard self.valid else { throw AmountError.invalidAmount }
    }
    
    init(currency: String, value: UInt64, fraction: UInt32) {
        self.currency = currency
        self.value = value
        self.fraction = fraction
    }
    
    init(fromDecoder decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        /* TODO: de-duplicate */
        guard let separatorIndex = string.firstIndex(of: ":") else { throw AmountError.invalidStringRepresentation }
        self.currency = String(string[..<separatorIndex])
        let amountStr = String(string[string.index(separatorIndex, offsetBy: 1)...])
        if let dotIndex = amountStr.firstIndex(of: ".") {
            let valueStr = String(amountStr[..<dotIndex])
            let fractionStr = String(amountStr[string.index(dotIndex, offsetBy: 1)...])
            guard let _value = UInt64(valueStr) else { throw AmountError.invalidStringRepresentation }
            self.value = _value
            self.fraction = 0
            var digitValue = Amount.fractionalBase / 10
            for char in fractionStr {
                guard let digit = char.wholeNumberValue else { throw AmountError.invalidStringRepresentation }
                self.fraction += digitValue * UInt32(digit)
                digitValue /= 10
            }
        } else {
            guard let _value = UInt64(amountStr) else { throw AmountError.invalidStringRepresentation }
            self.value = _value
            self.fraction = 0
        }
        guard self.valid else { throw AmountError.invalidAmount }
    }
    
    func copy() -> Amount {
        return Amount(currency: self.currency, value: self.value, fraction: self.fraction)
    }
    
    func normalizedCopy() throws -> Amount {
        let amount = self.copy()
        try amount.normalize()
        return amount
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
    
    func normalize() throws {
        if !valid {
            throw AmountError.invalidAmount
        }
        self.value += UInt64(self.fraction / Amount.fractionalBase)
        self.fraction = self.fraction % Amount.fractionalBase
        if !valid {
            throw AmountError.invalidAmount
        }
    }
    
    static func + (left: Amount, right: Amount) throws -> Amount {
        if left.currency != right.currency {
            throw AmountError.incompatibleCurrency
        }
        let leftNormalized = try left.normalizedCopy()
        let rightNormalized = try right.normalizedCopy()
        let result: Amount = leftNormalized
        result.value += rightNormalized.value
        result.fraction += rightNormalized.fraction
        try result.normalize()
        return result
    }
    
    static func - (left: Amount, right: Amount) throws -> Amount {
        if left.currency != right.currency {
            throw AmountError.incompatibleCurrency
        }
        let leftNormalized = try left.normalizedCopy()
        let rightNormalized = try right.normalizedCopy()
        if (leftNormalized.fraction < rightNormalized.fraction) {
            guard leftNormalized.value != 0 else { throw AmountError.negativeAmount }
            leftNormalized.value -= 1
            leftNormalized.fraction += Amount.fractionalBase
        }
        guard leftNormalized.value >= rightNormalized.value else { throw AmountError.negativeAmount }
        let diff = Amount.zero(currency: left.currency)
        diff.value = leftNormalized.value - rightNormalized.value
        diff.fraction = leftNormalized.fraction - rightNormalized.fraction
        try diff.normalize()
        return diff
    }
    
    static func == (left: Amount, right: Amount) throws -> Bool {
        if left.currency != right.currency {
            throw AmountError.incompatibleCurrency
        }
        let leftNormalized = try left.normalizedCopy()
        let rightNormalized = try right.normalizedCopy()
        return (leftNormalized.value == rightNormalized.value && leftNormalized.fraction == rightNormalized.fraction)
    }
    
    static func < (left: Amount, right: Amount) throws -> Bool {
        if left.currency != right.currency {
            throw AmountError.incompatibleCurrency
        }
        let leftNormalized = try left.normalizedCopy()
        let rightNormalized = try right.normalizedCopy()
        if (leftNormalized.value == rightNormalized.value) {
            return (leftNormalized.fraction < rightNormalized.fraction)
        } else {
            return (leftNormalized.value < rightNormalized.value)
        }
    }
    
    static func > (left: Amount, right: Amount) throws -> Bool {
        return try right < left
    }
    
    static func zero(currency: String) -> Amount {
        return Amount(currency: currency, value: 0, fraction: 0)
    }
}
