/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation

fileprivate let NONBREAKING: Character = "\u{00A0}"

public func SuperScriptDigit(_ number: UInt32) -> String {
    switch number {
        case 0: return String("\u{2070}")
        case 1: return String("\u{00B9}")
        case 2: return String("\u{00B2}")
        case 3: return String("\u{00B3}")
        case 4: return String("\u{2074}")
        case 5: return String("\u{2075}")
        case 6: return String("\u{2076}")
        case 7: return String("\u{2077}")
        case 8: return String("\u{2078}")
        case 9: return String("\u{2079}")
        default: return ""
    }
}

/// Errors for `Amount`.
enum AmountError: Error {
    /// The string cannot be parsed to create an `Amount`.
    case invalidStringRepresentation
    
    /// Could not compare or operate on two `Amount`s of different currencies.
    case incompatibleCurrency
    
    /// The amount is invalid. The value is either greater than the maximum, or the currency string is not 1-12 characters long.
    case invalidAmount
    
    /// The result of the operation would yield a negative amount.
    case negativeAmount
    
    /// The operation was division by zero.
    case divideByZero
}


/// A value of some currency.
public final class Amount: Codable, Hashable, @unchecked Sendable, CustomStringConvertible {        // TODO: @unchecked
    /// Format that a currency must match.
    private static let currencyRegex = #"^[-_*A-Za-z0-9]{1,12}$"#
    
    /// The largest possible value that can be represented.
    private static let maxValue: UInt64 = 1 << 52
    
    /// The greatest number of fractional digits that can be represented.
    private static let fractionalBaseDigits: UInt = 8

    /// The size of `integer` in relation to `fraction`.
    static func fractionalBase(_ power: UInt = Amount.fractionalBaseDigits) -> UInt32 {
        let exponent = power < Amount.fractionalBaseDigits
                     ? power : Amount.fractionalBaseDigits
        var base: UInt32 = 1
        for _ in 0..<exponent { base *= 10 }
        return base
    }

    /// Convenience re-definition
    func fractionalBase(_ power: UInt = Amount.fractionalBaseDigits) -> UInt32 {
        Self.fractionalBase(power)
    }

    public static let decimalSeparator = "."

    /// 3-char ISO 4217 code for global currency. Regional MUST be >= 4 letters
    /// The currency of the amount. Cannot be changed later, except...
    private var currency: String

    /// ... with this function
    public func setCurrency(_ newCurrency: String) {
        currency = newCurrency
    }

    /// Name & symbol{s) of the  currency of the amount. Cannot be changed later, except...
    private var currencyNm: String?
    private var currencySmbls: [Int : String]?

    /// ... with these functions
    public func setCurrencyName(_ newCurrency: String) {
        currencyNm = newCurrency
    }
    public func setCurrencySymbols(_ newCurrency: [Int : String]) {
        currencySmbls = newCurrency
    }

    /// The integer value of the amount (number to the left of the decimal point).
    var integer: UInt64
    
    /// The fractional value of the amount (number to the right of the decimal point).
    var fraction: UInt32

    public func hash(into hasher: inout Hasher) {
        hasher.combine(currency)
        if let normalized = try? normalizedCopy() {
            hasher.combine(normalized.integer)
            hasher.combine(normalized.fraction)
        } else {
            hasher.combine(integer)
            hasher.combine(fraction)
        }
    }

    /// The floating point representation of the integer.
    public var intValue: Double {
        Double(integer)
    }

    /// The floating point representation of the fraction.
    public var fracValue: Double {
        let oneThousand = 1000.0
        let base = Double(fractionalBase()) / oneThousand
        let thousandths = Double(fraction) / base
        return thousandths / oneThousand
    }

    /// The floating point representation of the value.
    /// Be careful, the value might exceed 15 digits which is the limit for Double.
    /// When more significant digits are needed, use valueAsTuple.
    public var value: Double {
        fraction == 0 ? intValue
                      : intValue + fracValue
    }

    /// The tuple representation of the value.
    public var valueAsDecimalTuple: (UInt64, UInt32) {
        (integer, fraction)
    }
    /// The tuple representation of the value.
    public var valueAsFloatTuple: (Double, Double) {
        (intValue, fracValue)
    }

    /// The string representation of the value, formatted as "`integer`.`fraction`",
    /// no trailing zeroes, no group separator.
    public var valueStr: String {
        if fraction == 0 {
            return String(integer)
        } else {
            var frac = UInt64(fraction)
            let base = UInt64(fractionalBase())
            var fracStr = ""
            while (frac > 0) {
                fracStr += String(frac / ( base / 10))
                frac = (frac * 10) % base
            }
            return "\(integer)\(Self.decimalSeparator)\(fracStr)"
        }
    }

    /// The string representation of the value, formatted as "`integer``fraction`",
    /// no group separator, no decimalSeparator, #inputDigits digits from fraction, padded with trailing zeroes
    public func plainString(inputDigits: UInt) -> String {
        let base = fractionalBase()
        var frac = fraction
        var fracStr = ""
        var i = inputDigits

        var nextchar: UInt32 {
            let fracChar = frac / (base / 10)
            frac = (frac * 10) % base
            return fracChar
        }

        if integer > 0 {
            while (i > 0) {
                fracStr += String(nextchar)
                i -= 1
            }
            return "\(integer)\(fracStr)"
        } else {
            while (i > 0) {
                let fracChar = nextchar
                // skip leading zeroes
                if fracStr.count > 0 || fracChar > 0 {
                    fracStr += String(fracChar)
                }
                i -= 1
            }
            return fracStr.count > 0 ? fracStr : "0"
        }
    }

    /// read-only getter
    public var currencyStr: String {
        currency
    }
    public var currencyName: String {
        currencyNm ?? currency
    }
    public var currencySymbol: String {
        currencySmbls?[0] ?? currency
    }

    /// The string representation of the amount, formatted as "`currency`:`integer`.`fraction`" (without space).
    public var description: String {
        "\(currency):\(valueStr)"
    }
    
    /// The string representation of the amount, formatted as "`integer`.`fraction` `currency`" (with non-breaking space).
    public var readableDescriptionNBS: String {
        return valueStr + String(NONBREAKING) + currency
    }
    
    /// The string representation of the amount, formatted as "`integer`.`fraction` `currency`" (with space (not non-breaking space)).
    public var readableDescription: String {
        return valueStr + " " + currency
    }

    /// Whether the value is valid. An amount is valid if and only if the currency is not empty and the value is less than the maximum allowed value.
    var valid: Bool {
        if currency.range(of: Amount.currencyRegex, options: .regularExpression) == nil {
            return false
        }
        return (integer <= Amount.maxValue && currency != "")
    }
    
    /// Whether this amount is zero or not.
    public var isZero: Bool {
        integer == 0 && fraction == 0
    }
    
    /// Initializes an amount by parsing a string representing the amount. The string should be formatted as "`currency`:`integer`.`fraction`".
    /// - Parameters:
    ///   - fromString: The string to parse.
    /// - Throws:
    ///   - `AmountError.invalidStringRepresentation` if the string cannot be parsed.
    ///   - `AmountError.invalidAmount` if the string can be parsed, but the resulting amount is not valid.
    public init(fromString string: String) throws {
        if let separatorIndex = string.firstIndex(of: ":") {
            self.currency = String(string[..<separatorIndex])
            let amountStr = String(string[string.index(separatorIndex, offsetBy: 1)...])
            if let dotIndex = amountStr.firstIndex(of: ".") {
                let integerStr = String(amountStr[..<dotIndex])
                let fractionStr = String(amountStr[string.index(dotIndex, offsetBy: 1)...])
                if (fractionStr.count > Self.fractionalBaseDigits) {
                    throw AmountError.invalidStringRepresentation
                }
                guard let intValue = UInt64(integerStr) else { throw AmountError.invalidStringRepresentation }
                self.integer = intValue
                self.fraction = 0
                var digitValue = fractionalBase() / 10
                for char in fractionStr {
                    guard let digit = char.wholeNumberValue else { throw AmountError.invalidStringRepresentation }
                    self.fraction += digitValue * UInt32(digit)
                    digitValue /= 10
                }
            } else {
                guard let intValue = UInt64(amountStr) else { throw AmountError.invalidStringRepresentation }
                self.integer = intValue
                self.fraction = 0
            }
        } else {
            self.currency = string
            self.integer = 0
            self.fraction = 0
        }
        guard self.valid else { throw AmountError.invalidAmount }
    }
    
    /// Initializes an amount with the specified currency, integer, and fraction.
    /// - Parameters:
    ///   - currency: The currency of the amount.
    ///   - integer: The integer value of the amount (number to the left of the decimal point).
    ///   - fraction: The fractional value of the amount (number to the right of the decimal point).
    public init(currency: String, integer: UInt64, fraction: UInt32) {
        self.currency = currency
        self.integer = integer
        self.fraction = fraction
    }
    public init(currency: String, cent: UInt64) {
        self.currency = currency
        self.integer = cent / 100   // For existing currencies, fractional digits could be 0, 2 or 3
        self.fraction = UInt32(cent - (self.integer * 100)) * (Self.fractionalBase() / 100)
    }

    /// Initializes an amount from a decoder.
    /// - Parameters:
    ///   - from: The decoder to extract the amount from.
    /// - Throws:
    ///   - `AmountError.invalidStringRepresentation` if the string cannot be parsed.
    ///   - `AmountError.invalidAmount` if the string can be parsed, but the resulting amount is not valid.
    required public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        try self.init(fromString: string)
    }
    
    /// Copies an amount.
    /// - Returns: A copy of the amount.
    public func copy() -> Amount {
        Amount(currency: currency, integer: integer, fraction: fraction)
    }
    
    /// Creates a normalized copy of an amount (the fractional part is strictly less than one unit of currency).
    /// - Returns: A copy of the amount that has been normalized
    func normalizedCopy() throws -> Amount {
        let amount = self.copy()
        try amount.normalize()
        return amount
    }
    
    /// Encodes an amount.
    /// - Parameters:
    ///   - to: The encoder to encode the amount with.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
    
    /// Normalizes an amount by reducing `fraction` until it is less than `fractionalBase()`, increasing `integer` appropriately.
    /// - Throws:
    ///   - `AmountError.invalidAmount` if the amount is invalid either before or after normalization.
    func normalize() throws {
        if !valid {
            throw AmountError.invalidAmount
        }
        integer += UInt64(fraction / fractionalBase())
        fraction = fraction % fractionalBase()
        if !valid {
            throw AmountError.invalidAmount
        }
    }
    
    /// Divides by ten
    public func shiftRight() {
        var remainder = UInt32(integer % 10)
        self.integer = integer / 10

        remainder = remainder * fractionalBase() + fraction
        self.fraction = remainder / 10
    }

    /// Multiplies by ten, then adds digit
    public func shiftLeft(add digit: UInt8, _ inputDigits: UInt) {
        if inputDigits > 0 {
            // how many digits to shift right (e.g. inputD=2 ==> shift:=6)
            let shift = Self.fractionalBaseDigits - inputDigits
            // mask to zero out fractions smaller than inputDigits
            let shiftMask = fractionalBase(shift)

            let carryMask = fractionalBase(Self.fractionalBaseDigits - 1)
            // get biggest fractional digit
            let carry = fraction / carryMask
            var remainder = fraction % carryMask
//            print("fraction: \(fraction) = \(carry) + \(remainder)")

            let shiftedInt = integer * 10 + UInt64(carry)
            if shiftedInt < Self.maxValue {
                self.integer = shiftedInt
//                print("remainder: \(remainder) / shiftMask \(shiftMask) = \(remainder / shiftMask)")
                remainder = (remainder / shiftMask) * 10
            } else { // will get too big
                     // Just swap the last significant digit for the one the user typed last
                if shiftMask >= 10 {
                    remainder = (remainder / (shiftMask / 10)) * 10
                } else {
                    remainder = (remainder / 10) * 10
                }
            }
            let sum = remainder + UInt32(digit)
            self.fraction = sum * shiftMask
   //        print("(remainder: \(remainder) + \(digit)) * base(shift) \(shiftMask) = fraction \(fraction)")
        } else {
            let shiftedInt = integer * 10 + UInt64(digit)
            if shiftedInt < Self.maxValue {
                self.integer = shiftedInt
            } else {
                self.integer = Self.maxValue
            }
            self.fraction = 0
        }
    }

    /// Sets all fractional digits after inputDigits to 0
    public func mask(_ inputDigits: UInt) {
        let mask = fractionalBase(Self.fractionalBaseDigits - inputDigits)
        let remainder = fraction % mask
        self.fraction -= remainder
    }

    /// Adds two amounts together.
    /// - Parameters:
    ///   - left: The amount on the left.
    ///   - right: The amount on the right.
    /// - Throws:
    ///   - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
    /// - Returns: The sum of `left` and `right`, normalized.
    public static func + (left: Amount, right: Amount) throws -> Amount {
        if left.currency != right.currency {
            throw AmountError.incompatibleCurrency
        }
        let leftNormalized = try left.normalizedCopy()
        let rightNormalized = try right.normalizedCopy()
        let result: Amount = leftNormalized
        result.integer += rightNormalized.integer
        result.fraction += rightNormalized.fraction
        try result.normalize()
        return result
    }
    
    /// Subtracts one amount from another.
    /// - Parameters:
    ///   - left: The amount on the left.
    ///   - right: The amount on the right.
    /// - Throws:
    ///   - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
    /// - Returns: The difference of `left` and `right`, normalized.
    public static func - (left: Amount, right: Amount) throws -> Amount {
        if left.currency != right.currency {
            throw AmountError.incompatibleCurrency
        }
        let leftNormalized = try left.normalizedCopy()
        let rightNormalized = try right.normalizedCopy()
        if (leftNormalized.fraction < rightNormalized.fraction) {
            guard leftNormalized.integer != 0 else { throw AmountError.negativeAmount }
            leftNormalized.integer -= 1
            leftNormalized.fraction += fractionalBase()
        }
        guard leftNormalized.integer >= rightNormalized.integer else { throw AmountError.negativeAmount }
        let diff = Amount.zero(currency: left.currency)
        diff.integer = leftNormalized.integer - rightNormalized.integer
        diff.fraction = leftNormalized.fraction - rightNormalized.fraction
        try diff.normalize()
        return diff
    }

    public static func diff (_ left: Amount, _ right: Amount) throws -> Amount {
        return try left > right ? left - right
                                : right - left
    }

    /// Divides an amount by a scalar, possibly introducing rounding error.
    /// - Parameters:
    ///   - dividend: The amount to divide.
    ///   - divisor: The scalar dividing `dividend`.
    /// - Returns: The quotient of `dividend` and `divisor`, normalized.
    public static func / (dividend: Amount, divisor: UInt32) throws -> Amount {
        guard divisor != 0 else { throw AmountError.divideByZero }
        let result = try dividend.normalizedCopy()
        if (divisor == 1) {
            return result
        }
        var remainder = result.integer % UInt64(divisor)
        result.integer = result.integer / UInt64(divisor)

        let fractionalBase64 = UInt64(fractionalBase())
        remainder = (remainder * fractionalBase64) + UInt64(result.fraction)
        result.fraction = UInt32(remainder / UInt64(divisor))
        try result.normalize()
        return result
    }
    
    /// Multiply an amount by a scalar.
    /// - Parameters:
    ///   - amount: The amount to multiply.
    ///   - factor: The scalar multiplying `amount`.
    /// - Returns: The product of `amount` and `factor`, normalized.
    public static func * (amount: Amount, factor: UInt32) throws -> Amount {
        let result = try amount.normalizedCopy()
        result.integer = result.integer * UInt64(factor)
        let fraction_tmp = UInt64(result.fraction) * UInt64(factor)
        result.integer += fraction_tmp / UInt64(fractionalBase())
        result.fraction = UInt32(fraction_tmp % UInt64(fractionalBase()))
        return result
    }
    
    /// Compares two amounts.
    /// - Parameters:
    ///   - left: The first amount.
    ///   - right: The second amount.
    /// - Throws:
    ///   - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
    /// - Returns: `true` if and only if the amounts have the same `integer` and `fraction` after normalization, `false` otherwise.
//    public static func == (left: Amount, right: Amount) throws -> Bool {
//        if left.currency != right.currency {
//            throw AmountError.incompatibleCurrency
//        }
//        let leftNormalized = try left.normalizedCopy()
//        let rightNormalized = try right.normalizedCopy()
//        return (leftNormalized.integer == rightNormalized.integer && leftNormalized.fraction == rightNormalized.fraction)
//    }
    
    public static func == (left: Amount, right: Amount) -> Bool {
        do {
            if left.currency != right.currency {
                throw AmountError.incompatibleCurrency
            }
            let leftNormalized = try left.normalizedCopy()
            let rightNormalized = try right.normalizedCopy()
            return (leftNormalized.integer == rightNormalized.integer && leftNormalized.fraction == rightNormalized.fraction)
        }
        catch {
            return false
        }
    }

    /// Compares two amounts.
    /// - Parameters:
    ///   - left: The amount on the left.
    ///   - right: The amount on the right.
    /// - Throws:
    ///   - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
    /// - Returns: `true` if and only if `left` is lesser than `right` after normalization, `false` otherwise.
    public static func < (left: Amount, right: Amount) throws -> Bool {
        if left.currency != right.currency {
            throw AmountError.incompatibleCurrency
        }
        let leftNormalized = try left.normalizedCopy()
        let rightNormalized = try right.normalizedCopy()
        if (leftNormalized.integer == rightNormalized.integer) {
            return (leftNormalized.fraction < rightNormalized.fraction)
        } else {
            return (leftNormalized.integer < rightNormalized.integer)
        }
    }
    
    /// Compares two amounts.
    /// - Parameters:
    ///   - left: The amount on the left.
    ///   - right: The amount on the right.
    /// - Throws:
    ///   - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
    /// - Returns: `true` if and only if `left` is lesser than or equal to `right` after normalization, `false` otherwise.
    public static func <= (left: Amount, right: Amount) throws -> Bool {
        return try left < right || left == right
    }
    
    /// Compares two amounts.
    /// - Parameters:
    ///   - left: The amount on the left.
    ///   - right: The amount on the right.
    /// - Throws:
    ///   - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
    /// - Returns: `true` if and only if `left` is greater than `right` after normalization, `false` otherwise.
    public static func > (left: Amount, right: Amount) throws -> Bool {
        return try right < left
    }
    
    /// Compares two amounts.
    /// - Parameters:
    ///   - left: The amount on the left.
    ///   - right: The amount on the right.
    /// - Throws:
    ///   - `AmountError.incompatibleCurrency` if `left` and `right` do not share the same currency.
    /// - Returns: `true` if and only if `left` is greater than or equal `right` after normalization, `false` otherwise.
    public static func >= (left: Amount, right: Amount) throws -> Bool {
        return try left > right || left == right
    }
    
    /// Creates the amount representing zero in a given currency.
    /// - Parameters:
    ///   - currency: The currency to use.
    /// - Returns: The zero amount for `currency`.
    public static func zero(currency: String) -> Amount {
        return Amount(currency: currency, integer: 0, fraction: 0)
    }

    public static func amountFromCents(_ currency: String, _ cents: UInt64) -> Amount {
        let amount100 = Amount(currency: currency, integer: cents, fraction: 0)
        do {
            let amount = try amount100 / 100
            return amount
        } catch {       // shouldn't happen, but if it does then truncate
            return Amount(currency: currency, integer: cents / 100, fraction: 0)
        }
    }
}
// MARK: -
extension Amount: Identifiable {
    // needed to be passed as value for .sheet
    public var id: Amount {self}
}
