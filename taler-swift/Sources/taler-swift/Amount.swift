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

/**
    Errors for `Amount`.
 */
enum AmountError: Error {
    /**
        The string cannot be parsed to create an `Amount`.
     */
    case invalidStringRepresentation
    
    /**
        Could not compare or operate on two `Amount`s of different currencies.
     */
    case incompatibleCurrency
    
    /**
        The amount is invalid. The value is either greater than the maximum, or the currency is the empty string.
     */
    case invalidAmount
    
    /**
        The result of the operation would yield a negative amount.
     */
    case negativeAmount
    
    /**
        The operation was division by zero.
     */
    case divideByZero
}

/**
    A value of a currency.
 */
public class Amount: Codable, CustomStringConvertible {
    /**
        The largest possible value that can be represented.
     */
    private static let maxValue: UInt64 = 1 << 52
    
    /**
        The size of `value` in relation to `fraction`.
     */
    private static let fractionalBase: UInt32 = 100000000
    
    /**
        The greatest number of decimal digits that can be represented.
     */
    private static let fractionalBaseDigits: UInt = 8
    
    /**
        The currency of the amount.
     */
    var currency: String
    
    /**
        The value of the amount (number to the left of the decimal point).
     */
    var value: UInt64
    
    /**
        The fractional value of the amount (number to the right of the decimal point).
     */
    var fraction: UInt32
    
    /**
        The string representation of the amount, formatted as "`currency`:`value`.`fraction`".
     */
    public var description: String {
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
    
    /**
        Whether the value is valid. An amount is valid if and only if the currency is not empty and the value is less than the maximum allowed value.
     */
    var valid: Bool {
        return (value <= Amount.maxValue && currency != "")
    }
    
    /**
        Initializes an amount by parsing a string representing the amount. The string should be formatted as "`currency`:`value`.`fraction`".
     
        - Parameters:
            - fromString: The string to parse.
     
        - Throws:
            - `AmountError.invalidStringRepresentation` if the string cannot be parsed.
            - `AmountError.invalidAmount` if the string can be parsed, but the resulting amount is not valid.
     */
    public init(fromString string: String) throws {
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
    
    /**
        Initializes an amount with the specified currency, value, and fraction.
     
        - Parameters:
            - currency: The currency of the amount.
            - value: The value of the amount (number to the left of the decimal point).
            - fraction: The fractional value of the amount (number to the right of the decimal point).
     */
    init(currency: String, value: UInt64, fraction: UInt32) {
        self.currency = currency
        self.value = value
        self.fraction = fraction
    }
    
    /**
        Initializes an amount from a decoder.
     
        - Parameters:
            - fromDecoder: The decoder to extract the amount from.
     
        - Throws:
            - `AmountError.invalidStringRepresentation` if the string cannot be parsed.
            - `AmountError.invalidAmount` if the string can be parsed, but the resulting amount is not valid.
     */
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
    
    /**
        Copies an amount.
     
        - Returns: A copy of the amount.
     */
    func copy() -> Amount {
        return Amount(currency: self.currency, value: self.value, fraction: self.fraction)
    }
    
    /**
        Creates a normalized copy of an amount.
     
        - Returns: A copy of the amount that has been normalized
     */
    func normalizedCopy() throws -> Amount {
        let amount = self.copy()
        try amount.normalize()
        return amount
    }
    
    /**
        Encodes an amount.
     
        - Parameters:
            - to: The encoder to encode the amount with.
     */
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
    
    /**
        Normalizes an amount by reducing `fraction` until it is less than `Amount.fractionalBase`, increasing `value` appropriately.
     
        - Throws:
            - `AmountError.invalidAmount` if the amount is invalid either before or after normalization.
     */
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
    
    /**
        Adds two amounts together.
     
        - Parameters:
            - left: The amount on the left.
            - right: The amount on the right.
     
        - Throws:
            - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
     
        - Returns: The sum of `left` and `right`, normalized.
     */
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
    
    /**
        Subtracts one amount from another.
     
        - Parameters:
            - left: The amount on the left.
            - right: The amount on the right.
     
        - Throws:
            - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
     
        - Returns: The difference of `left` and `right`, normalized.
     */
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
    
    /**
        Divides an amount by a scalar, possibly introducing rounding error.
     
        - Parameters:
            - dividend: The amount to divide.
            - divisor: The scalar dividing `dividend`.
     
        - Returns: The quotient of `dividend` and `divisor`, normalized.
     */
    static func / (dividend: Amount, divisor: UInt32) throws -> Amount {
        guard divisor != 0 else { throw AmountError.divideByZero }
        let result = try dividend.normalizedCopy()
        if (divisor == 1) {
            return result
        }
        var remainder = result.value % UInt64(divisor)
        result.value = result.value / UInt64(divisor)
        remainder = (remainder * UInt64(Amount.fractionalBase)) + UInt64(result.fraction)
        result.fraction = UInt32(remainder) / divisor
        try result.normalize()
        return result
    }
    
    /**
        Multiply an amount by a scalar.
     
        - Parameters:
            - amount: The amount to multiply.
            - factor: The scalar multiplying `amount`.
     
        - Returns: The product of `amount` and `factor`, normalized.
     */
    static func * (amount: Amount, factor: UInt32) throws -> Amount {
        let result = try amount.normalizedCopy()
        result.value = result.value * UInt64(factor)
        let fraction_tmp = UInt64(result.fraction) * UInt64(factor)
        result.value += fraction_tmp / UInt64(Amount.fractionalBase)
        result.fraction = UInt32(fraction_tmp % UInt64(Amount.fractionalBase))
        return result
    }
    
    /**
        Compares two amounts.
     
        - Parameters:
            - left: The first amount.
            - right: The second amount.
     
        - Throws:
            - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
     
        - Returns: `true` if and only if the amounts have the same `value` and `fraction` after normalization, `false` otherwise.
     */
    static func == (left: Amount, right: Amount) throws -> Bool {
        if left.currency != right.currency {
            throw AmountError.incompatibleCurrency
        }
        let leftNormalized = try left.normalizedCopy()
        let rightNormalized = try right.normalizedCopy()
        return (leftNormalized.value == rightNormalized.value && leftNormalized.fraction == rightNormalized.fraction)
    }
    
    /**
        Compares two amounts.
     
        - Parameters:
            - left: The amount on the left.
            - right: The amount on the right.
     
        - Throws:
            - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
     
        - Returns: `true` if and only if `left` is smaller than `right` after normalization, `false` otherwise.
     */
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
    
    /**
        Compares two amounts.
     
        - Parameters:
            - left: The amount on the left.
            - right: The amount on the right.
     
        - Throws:
            - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
     
        - Returns: `true` if and only if `left` is bigger than `right` after normalization, `false` otherwise.
     */
    static func > (left: Amount, right: Amount) throws -> Bool {
        return try right < left
    }
    
    /**
        Creates the amount representing zero in a given currency.
     
        - Parameters:
            - currency: The currency to use.
     
        - Returns: The zero amount for `currency`.
     */
    static func zero(currency: String) -> Amount {
        return Amount(currency: currency, value: 0, fraction: 0)
    }
}
