/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation
import SwiftUI
import taler_swift

extension Locale {
    static var preferredLanguageCode: String {
        guard let preferredLanguage = preferredLanguages.first,
              let code = Locale(identifier: preferredLanguage).languageCode else {
            return "en"
        }
        return code
    }

    static var preferredLanguageCodes: [String] {
        return Locale.preferredLanguages.compactMap({Locale(identifier: $0).languageCode})
    }
}
// MARK: -
extension Locale {
    func leadingCurrencySymbol() -> Bool {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.locale = self

        let positiveFormat = currencyFormatter.positiveFormat as NSString
        let currencySymbolLocation = positiveFormat.range(of: "¤").location

        return currencySymbolLocation == 0
    }
}
// MARK: -
extension Amount {
    func formatted(_ currencyInfo: CurrencyInfo?, isNegative: Bool = false,
                           useISO: Bool = false, a11yDecSep: String? = nil
    ) -> (String, String) {
        if let currencyInfo {
            let a11y = currencyInfo.string(for: valueAsFloatTuple,
                                    isNegative: isNegative,
                                      currency: currencyStr,
                                        useISO: true,
                                    a11yDecSep: a11yDecSep)
            let strg = currencyInfo.string(for: valueAsFloatTuple,
                                    isNegative: isNegative,
                                      currency: currencyStr,
                                        useISO: useISO,
                                    a11yDecSep: nil)
            return (strg, a11y)
        } else {
            return (valueStr, valueStr)
        }
    }

    // this is the function to use
    func formatted(_ scope: ScopeInfo?, isNegative: Bool,
                    useISO: Bool = false, a11yDecSep: String? = nil
    ) -> (String, String) {
        let controller = Controller.shared
        if let scope {
            if let currencyInfo = controller.info(for: scope) {
                return self.formatted(currencyInfo, isNegative: isNegative, useISO: useISO, a11yDecSep: a11yDecSep)
            }
        }
        return (self.readableDescription, self.readableDescription)
    }

    func formatted(specs: CurrencySpecification?, isNegative: Bool,
                   scope: ScopeInfo? = nil, useISO: Bool = false
    ) -> (String, String) {
        if let specs {
            let formatter = CurrencyFormatter.formatter(currency: currencyStr, specs: specs)
            let currencyInfo = CurrencyInfo(specs: specs, formatter: formatter)
            return formatted(currencyInfo, isNegative: isNegative, useISO: useISO)
        } else if let scope {
            return formatted(scope, isNegative: isNegative, useISO: useISO)
        }
        return (self.readableDescription, self.readableDescription)
    }

    func inputDigits(_ currencyInfo: CurrencyInfo) -> UInt {
        let inputDigits = currencyInfo.specs.fractionalInputDigits
        if inputDigits < 0 { return 0 }
        if inputDigits > 8 { return 8}
        return UInt(inputDigits)
    }

    func addDigit(_ digit: UInt8, currencyInfo: CurrencyInfo) {
        shiftLeft(add: digit, inputDigits(currencyInfo))
    }

    func removeDigit(_ currencyInfo: CurrencyInfo) {
        shiftRight()                        // divide by 10
        mask(inputDigits(currencyInfo))     // replace all digits after #inputDigit with 0
    }

    func plainString(_ currencyInfo: CurrencyInfo) -> String {
        return plainString(inputDigits: inputDigits(currencyInfo))
    }
}
// MARK: -
public struct CurrencyInfo: Sendable {
//    let scope: ScopeInfo
    let specs: CurrencySpecification
    let formatter: CurrencyFormatter

//    public static func zero(_ currency: String) -> CurrencyInfo {
    public static func zero(_ currency: String, nu: Bool = false) -> CurrencyInfo {
        let null = nu ? "ヌ"                // use `nu´ for Null
                      : EMPTYSTRING
        let specs = CurrencySpecification(name: currency,
                                 commonAmounts: nil,
                         fractionalInputDigits: 0,
                        fractionalNormalDigits: 0,
                  fractionalTrailingZeroDigits: 0,
                                  altUnitNames: [0 : null])
        let formatter = CurrencyFormatter.formatter(currency: currency, specs: specs)
        return CurrencyInfo(specs: specs, formatter: formatter)
    }

    public static func euro() -> CurrencyInfo {
        let currency = EUR_4217
        let specs = CurrencySpecification(name: "Euro",
                                 commonAmounts: nil,
                         fractionalInputDigits: 2,
                        fractionalNormalDigits: 2,
                  fractionalTrailingZeroDigits: 2,
                                  altUnitNames: [0 : "€"])                      // ensure altUnitSymbol
        let formatter = CurrencyFormatter.formatter(currency: currency, specs: specs)
    print(formatter.name ?? formatter.altUnitSymbol ?? formatter.altUnitName0 ?? formatter.currency)
        return CurrencyInfo(specs: specs, formatter: formatter)
    }

    public static func francs() -> CurrencyInfo {
        let currency = CHF_4217
        let specs = CurrencySpecification(name: "Franken",
                                 commonAmounts: nil,
                         fractionalInputDigits: 2,
                        fractionalNormalDigits: 2,
                  fractionalTrailingZeroDigits: 2,
                                  altUnitNames: [0 : " Fr."])                   // ensure altUnitName0
        let formatter = CurrencyFormatter.formatter(currency: currency, specs: specs)
    print(formatter.name ?? formatter.altUnitSymbol ?? formatter.altUnitName0 ?? formatter.currency)
        return CurrencyInfo(specs: specs, formatter: formatter)
    }


    var currency: String { formatter.currency }
    private var altUnitName0: String? { formatter.altUnitName0 }
    private var altUnitSymbol: String? { formatter.altUnitSymbol }
    var name: String { specs.name }
    var symbol: String { altUnitSymbol ?? name }      // fall back to name if no symbol defined
    var hasSymbol: Bool {
        if symbol != name {
            let count = symbol.count
            return count > 0 && count <= 3
        }
        return false
    }
    var commonAmounts: [Amount]? { specs.commonAmounts }

    /// returns all characters left from the decimalSeparator
    func integerPartStr(_ integerStr: String, decimalSeparator: String) -> String {
        if let integerIndex = integerStr.endIndex(of: decimalSeparator) {
            // decimalSeparator was found ==> return all characters left of it
            return String(integerStr[..<integerIndex])
        }
        guard let firstChar = integerStr.first else { return "0" }    // TODO: should NEVER happen! Show error
        let digitSet = CharacterSet.decimalDigits
        if digitSet.contains(firstChar) {
            // Currency Symbol is after the amount ==> return only the digits
            return String(integerStr.unicodeScalars.filter { digitSet.contains($0) })
        } else {
            // Currency Symbol is in front of the amount ==> return everything
            return integerStr
        }
    }

    func currencyString(_ aString: String, useISO: Bool = false) -> String {
        if !useISO {
            if let aSymbol = altUnitSymbol {
                let symbolString = aString.replacingOccurrences(of: formatter.currencySymbol, with: aSymbol)
                return symbolString.replacingOccurrences(of: formatter.currencyCode, with: aSymbol)
            }
            if let aName = altUnitName0 {
                let spacedName = formatter.leadingCurrencySymbol ? aName + SPACE
                                                                 : SPACE + aName
                let spacedString1 = aString.replacingOccurrences(of: formatter.currencySymbol, with: spacedName)
                let spacedString2 = spacedString1.replacingOccurrences(of: formatter.currencyCode, with: spacedName)
                let spacedString3 = spacedString2.replacingOccurrences(of: "  ", with: " ")  // ensure we have only 1 space
                return spacedString3
            }
        }
        let currency = formatter.currency
        if !currency.isEmpty {
            let spacedName = formatter.leadingCurrencySymbol ? currency + SPACE
                                                             : SPACE + currency
            let spacedString1 = aString.replacingOccurrences(of: formatter.currencySymbol, with: spacedName)
            let spacedString2 = spacedString1.replacingOccurrences(of: formatter.currencyCode, with: spacedName)
            let spacedString3 = spacedString2.replacingOccurrences(of: "  ", with: " ")  // ensure we have only 1 space
            return spacedString3
        }
        return aString
    }

    // TODO: use valueAsDecimalTuple instead of valueAsFloatTuple
    func string(for valueTuple: (Double, Double), isNegative: Bool, currency: String,
                        useISO: Bool = false, a11yDecSep: String? = nil) -> String {
        formatter.setUseISO(useISO)
        let (integer, fraction) = valueTuple
        if let integerStr = formatter.string(for: isNegative ? -integer : integer) {
            let integerSpaced = integerStr.spaced
            if fraction == 0 {
                return currencyString(integerSpaced, useISO: useISO)   // formatter already added trailing zeroes
            }
            if let fractionStr = formatter.string(for: fraction) {
                let fractionSpaced = fractionStr.spaced
                if let decimalSeparator = formatter.currencyDecimalSeparator {
                    if let fractionIndex = fractionSpaced.endIndex(of: decimalSeparator) {
                        var fractionPartStr = String(fractionSpaced[fractionIndex...])
                        var resultStr = integerPartStr(integerSpaced, decimalSeparator: decimalSeparator)
                        if !resultStr.contains(decimalSeparator) {
                            resultStr += decimalSeparator
                        }
//            print(resultStr, fractionPartStr)
                        var fractionCnt = 1
                        for character in fractionPartStr {
                            let isSuper = fractionCnt > specs.fractionalNormalDigits
                            let charStr = String(character)
                            if let digit = Int(charStr) {
                                let digitStr = isSuper ? SuperScriptDigits(charStr) : charStr
                                resultStr += digitStr
                                if (fractionCnt > 0) { fractionCnt += 1 }
                            } else {
                                // probably the Currency Code or Symbol. Just pass it on...
                                resultStr += charStr
                                // make sure any following digits (part of the currency name) are not converted to SuperScript
                                fractionCnt = 0
                            }
                        }
//            print(resultStr)
                        if let a11yDecSep {
                            resultStr = resultStr.replacingOccurrences(of: decimalSeparator, with: a11yDecSep)
                        }
                        return currencyString(resultStr, useISO: useISO)
                    }
                    // if we arrive here then fractionStr doesn't have a decimal separator. Yikes!
                }
                // if we arrive here then the formatter doesn't have a currencyDecimalSeparator
            }
            // if we arrive here then we do not get a formatted string for fractionStr. Yikes!
        }
        // if we arrive here then we do not get a formatted string for integerStr. Yikes!
        // TODO: log.error(formatter doesn't work)
        // we need to format ourselves
//        var currencyName = scope.currency
        var currencyName = currency
        if !useISO {
            if let altUnitName0 {
                currencyName = altUnitName0
            }
        }
        var madeUpStr = currencyName + (isNegative ? " -" + String(integer)
                                                   : " " + String(integer))
//        let homeCurrency = Locale.current.currency      //'currency' is only available in iOS 16 or newer
        madeUpStr += formatter.currencyDecimalSeparator ?? Locale.current.decimalSeparator ?? "."
        madeUpStr += String(String(fraction).dropFirst())       // remove the leading 0
        // TODO: fractionalNormalDigits, fractionalTrailingZeroDigits
        return madeUpStr
    }
}
// MARK: -
public struct CurrencySpecification: Codable, Equatable, Hashable, Sendable {
    enum CodingKeys: String, CodingKey {
        case name
        case commonAmounts = "common_amounts"
        case fractionalInputDigits = "num_fractional_input_digits"
        case fractionalNormalDigits = "num_fractional_normal_digits"
        case fractionalTrailingZeroDigits = "num_fractional_trailing_zero_digits"
        case altUnitNames = "alt_unit_names"
    }
    /// some name for this CurrencySpecification
    let name: String
    let commonAmounts: [Amount]?
    /// how much digits the user may enter after the decimal separator
    let fractionalInputDigits: Int
    /// €,$,£: 2;  some arabic currencies: 3,  ¥: 0
    let fractionalNormalDigits: Int
    /// usually same as numFractionalNormalDigits, but e.g. might be 2 for ¥
    let fractionalTrailingZeroDigits: Int
    /// map of powers of 10 to alternative currency names / symbols
    /// must always have an entry under "0" that defines the base name
    /// e.g.  "0 => €" or "3 => k€". For BTC, would be "0 => BTC, -3 => mBTC".
    /// This way, we can also communicate the currency symbol to be used.
    let altUnitNames: [Int : String]?
}
// MARK: -
public class CurrencyFormatter: NumberFormatter {

    var name: String?
    var altUnitName0: String?           // specs.altUnitNames[0] should have either the name
    var altUnitSymbol: String?          // specs.altUnitNames[0] should have the Symbol ($,€,¥)
    var currency: String
    var leadingCurrencySymbol: Bool
    /// factory

    static func formatter(currency: String, specs: CurrencySpecification) -> CurrencyFormatter {
        let formatter = CurrencyFormatter()
        if let altUnitNameZero = specs.altUnitNames?[0] {
            if altUnitNameZero.hasPrefix(SPACE) {
                formatter.altUnitName0 = String(altUnitNameZero.dropFirst())
            } else {
                formatter.altUnitSymbol = altUnitNameZero
            }
        }
        formatter.name = specs.name
        formatter.currency = currency
//        formatter.setCode(to: EUR_4217)
//        formatter.setSymbol(to: "€")
        formatter.setMinimumFractionDigits(specs.fractionalTrailingZeroDigits)
        return formatter
    }

    public override init() {
        self.name = nil
        self.altUnitName0 = nil
        self.altUnitSymbol = nil
        self.currency = EMPTYSTRING
        self.leadingCurrencySymbol = false
        super.init()
//        self.currencyCode = EUR_4217
//        self.currencySymbol = "€"
        self.locale = Locale.autoupdatingCurrent                                // TODO: Yikes, might override my currency! Needs testing!
        if #available(iOS 16.4, *) {
            let currency = self.locale.currency
            if let currencyCode = currency?.identifier {
                self.name = self.locale.localizedString(forCurrencyCode: currencyCode)
            }
        } else {
            if let currencyCode = self.locale.currencyCode {
                self.name = self.locale.localizedString(forCurrencyCode: currencyCode)
            }
        }
        self.usesGroupingSeparator = true
        self.numberStyle = .currencyISOCode         // .currency
        self.maximumFractionDigits = 8              // ensure that formatter will not round

//        self.currencyCode = code              // EUR, USD, JPY, GBP
//        self.currencySymbol = symbol
//        self.internationalCurrencySymbol =
//        self.minimumFractionDigits = fractionDigits
//        self.maximumFractionDigits = fractionDigits
//        self.groupingSize = 3                 // thousands
//        self.groupingSeparator = ","
//        self.decimalSeparator = "."
        let positiveFormat = self.positiveFormat as NSString
        let currencySymbolLocation = positiveFormat.range(of: "¤").location
        self.leadingCurrencySymbol = currencySymbolLocation == 0
    }

    func setUseISO(_ useISO: Bool) {
        numberStyle = useISO ? .currencyISOCode : .currency     // currencyPlural or currencyAccounting
    }

//    func setCode(to code:String) {
//        currencyCode = code
//    }

//    func setSymbol(to symbol:String) {
//        currencySymbol = symbol
//    }

    func setMinimumFractionDigits(_ digits: Int) {
        minimumFractionDigits = digits
    }

    func setLocale(to newLocale: String) {
        locale = Locale(identifier: newLocale)
        maximumFractionDigits = 8               // ensure that formatter will not round
//        NumberFormatter.RoundingMode
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
// MARK: -
#if DEBUG
func PreviewCurrencyInfo(_ currency: String, digits: Int) -> CurrencyInfo {
    let unitName = digits == 0 ? "テ" : "ク"  // do not use real currency symbols like "¥" : "€"
    let specs = CurrencySpecification(name: currency,
                             commonAmounts: nil,
                     fractionalInputDigits: digits,
                    fractionalNormalDigits: digits,
              fractionalTrailingZeroDigits: digits,
                              altUnitNames: [0 : unitName])
    let previewFormatter = CurrencyFormatter.formatter(currency: currency, specs: specs)
    return CurrencyInfo(specs: specs, formatter: previewFormatter)
}
#endif
