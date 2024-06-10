/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
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

extension Amount {
    func formatted(_ currencyInfo: CurrencyInfo?, useSymbol: Bool = true) -> String {
        if let currencyInfo {
            return currencyInfo.string(for: valueAsFloatTuple, useSymbol: useSymbol)
        } else {
            return valueStr
        }
    }

    func formatted(useSymbol: Bool = true) -> String {
        let controller = Controller.shared
        if let currencyInfo = controller.info(for: self.currencyStr) {
            return self.formatted(currencyInfo, useSymbol: useSymbol)
        }
        return self.readableDescription
    }

    func formatted(specs: CurrencySpecification?, scope: ScopeInfo? = nil) -> String {
        if let specs {
            let myScope = scope ?? ScopeInfo(type: .madeUp, currency: currencyStr)
            let formatter = CurrencyFormatter.formatter(scope: myScope, specs: specs)
            let currencyInfo = CurrencyInfo(scope: myScope, specs: specs, formatter: formatter)
            return formatted(currencyInfo)
        }
        return formatted()
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

public struct CurrencyInfo {
    let scope: ScopeInfo
    let specs: CurrencySpecification
    let formatter: CurrencyFormatter

    public static func zero(_ currency: String) -> CurrencyInfo {
        let scope = ScopeInfo(type: .global, currency: currency)
        let specs = CurrencySpecification(name: currency,
                         fractionalInputDigits: 0,
                        fractionalNormalDigits: 0,
                  fractionalTrailingZeroDigits: 0,
                                  altUnitNames: [0 : "ヌ"])  // use `nu´ for Null
        let formatter = CurrencyFormatter.formatter(scope: scope, specs: specs)
        return CurrencyInfo(scope: scope, specs: specs, formatter: formatter)
    }

    public static func euro() -> CurrencyInfo {
        let currency = "Euro"
        let scope = ScopeInfo(type: .global, currency: currency)
        let specs = CurrencySpecification(name: currency,
                         fractionalInputDigits: 2,
                        fractionalNormalDigits: 2,
                  fractionalTrailingZeroDigits: 2,
                                  altUnitNames: [0 : "€"])
        let formatter = CurrencyFormatter.formatter(scope: scope, specs: specs)
        return CurrencyInfo(scope: scope, specs: specs, formatter: formatter)
    }

    public static func francs() -> CurrencyInfo {
        let currency = "CHF"
        let scope = ScopeInfo(type: .global, currency: currency)
        let specs = CurrencySpecification(name: currency,
                                          fractionalInputDigits: 2,
                                          fractionalNormalDigits: 2,
                                          fractionalTrailingZeroDigits: 2,
                                          altUnitNames: [0 : "CHF"])
        let formatter = CurrencyFormatter.formatter(scope: scope, specs: specs)
        return CurrencyInfo(scope: scope, specs: specs, formatter: formatter)
    }

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

    func symbol() -> String? {
        formatter.altUnitName0
    }

    func currencyString(_ euroString: String, useSymbol: Bool = true) -> String {
        if useSymbol {
            if let altUnitName0 = formatter.altUnitName0 {
                let symbolString = euroString.replacingOccurrences(of: formatter.currencySymbol, with: altUnitName0)
                return symbolString.replacingOccurrences(of: formatter.currencyCode, with: altUnitName0)
            }
        }
        let nameString = euroString.replacingOccurrences(of: formatter.currencySymbol, with: formatter.currencyName)
        return nameString.replacingOccurrences(of: formatter.currencyCode, with: formatter.currencyName)
    }

    // TODO: use valueAsDecimalTuple instead of valueAsFloatTuple
    func string(for valueTuple: (Double, Double), useSymbol: Bool = true) -> String {
        formatter.setUseSymbol(useSymbol)
        let (integer, fraction) = valueTuple
        if let integerStr = formatter.string(for: integer) {
            if fraction == 0 {
                return currencyString(integerStr.nbs(), useSymbol: useSymbol)   // formatter already added trailing zeroes
            }
            if let fractionStr = formatter.string(for: fraction) {
                if let decimalSeparator = formatter.currencyDecimalSeparator {
                    if let fractionIndex = fractionStr.endIndex(of: decimalSeparator) {
                        var fractionPartStr = String(fractionStr[fractionIndex...])
                        var resultStr = integerPartStr(integerStr, decimalSeparator: decimalSeparator)
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
                        return currencyString(resultStr.nbs(), useSymbol: useSymbol)
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
        var currencyName = scope.currency
        if useSymbol {
            if let symbol = symbol() {
                currencyName = symbol
            }
        }
        var madeUpStr = currencyName + " " + String(integer)
//        let homeCurrency = Locale.current.currency      //'currency' is only available in iOS 16 or newer
        madeUpStr += Locale.current.decimalSeparator ?? "."     // currencyDecimalSeparator
        madeUpStr += String(String(fraction).dropFirst())       // remove the leading 0
        // TODO: fractionalNormalDigits, fractionalTrailingZeroDigits
        return madeUpStr.nbs()
    }
}

public struct CurrencySpecification: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case fractionalInputDigits = "num_fractional_input_digits"
        case fractionalNormalDigits = "num_fractional_normal_digits"
        case fractionalTrailingZeroDigits = "num_fractional_trailing_zero_digits"
        case altUnitNames = "alt_unit_names"
    }
    /// some name for this CurrencySpecification
    let name: String
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


public class CurrencyFormatter: NumberFormatter {

    var longName: String
    var altUnitName0: String?           // specs.altUnitNames[0] should have the Symbol ($,€,¥)
    var currencyName: String
    var leadingCurrencySymbol: Bool
    /// factory
    static func formatter(scope: ScopeInfo, specs: CurrencySpecification) -> CurrencyFormatter {
        let formatter = CurrencyFormatter()
        formatter.longName = specs.name
        formatter.altUnitName0 = specs.altUnitNames?[0]
        formatter.currencyName = scope.currency
//        formatter.setCode(to: "EUR")
//        formatter.setSymbol(to: "€")
        formatter.setMinimumFractionDigits(specs.fractionalTrailingZeroDigits)
        return formatter
    }

    public override init() {
        self.longName = "Euro"
        self.altUnitName0 = "€"
        self.currencyName = "EUR"
        self.leadingCurrencySymbol = false
        super.init()
        self.currencyCode = "EUR"
        self.currencySymbol = "€"
        self.locale = Locale.autoupdatingCurrent
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

    func setUseSymbol(_ useSymbol: Bool) {
        numberStyle = useSymbol ? .currency : .currencyISOCode
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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
// MARK: -
#if DEBUG
func PreviewCurrencyInfo(_ currency: String, digits: Int) -> CurrencyInfo {
    let unitName = digits == 0 ? "テ" : "ク"  // do not use real currency symbols like "¥" : "€"
    let scope = ScopeInfo(type: .global, currency: currency)
    let specs = CurrencySpecification(name: currency,
                                      fractionalInputDigits: digits,
                                      fractionalNormalDigits: digits,
                                      fractionalTrailingZeroDigits: digits,
                                      altUnitNames: [0 : unitName])
    let previewFormatter = CurrencyFormatter.formatter(scope: scope, specs: specs)
    return CurrencyInfo(scope: scope, specs: specs, formatter: previewFormatter)
}
#endif
