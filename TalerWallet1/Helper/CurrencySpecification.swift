/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift

public struct CurrencyInfo {
    let scope: ScopeInfo
    let specs: CurrencySpecification
    let formatter: CurrencyFormatter
}

public struct CurrencySpecification2: Codable, Sendable {
    let currencySpecification: CurrencySpecification
}

public struct CurrencySpecification: Codable, Sendable {
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case decimalSeparator = "decimal_separator"
        case groupSeparator = "group_separator"
        case fractionalInputDigits = "num_fractional_input_digits"
        case fractionalNormalDigits = "num_fractional_normal_digits"
        case fractionalTrailingZeroDigits = "num_fractional_trailing_zero_digits"
        case isCurrencyNameLeading = "is_currency_name_leading"
        case altUnitNames = "alt_unit_names"
    }
    /// some name for this CurrencySpecification
    let name: String
    /// e.g. “.” for $, and “,” for €
    let decimalSeparator: String
    /// e.g. “,” for $, and “.” or “ ” for €     (France uses a narrow space character)
    let groupSeparator: String?
    /// how much digits the user may enter after the decimal separator
    let fractionalInputDigits: Int
    /// €,$,£: 2;  some arabic currencies: 3,  ¥: 0
    let fractionalNormalDigits: Int
    /// usually same as numFractionalNormalDigits, but e.g. might be 2 for ¥
    let fractionalTrailingZeroDigits: Int
    /// true for “$ 3.50”;  false for “3,50 €”
    let isCurrencyNameLeading: Bool
    /// map of powers of 10 to alternative currency names / symbols
    /// must always have an entry under "0" that defines the base name
    /// e.g.  "0 => €" or "3 => k€". For BTC, would be "0 => BTC, -3 => mBTC".
    /// This way, we can also communicate the currency symbol to be used.
    let altUnitNames: [Int : String]?
}


public class CurrencyFormatter: NumberFormatter {

    var hasAltUnitName0: Bool   // specs.altUnitNames[0] should have the Symbol ($,€,¥)
    /// factory
    static func formatter(scope: ScopeInfo, specs: CurrencySpecification) -> CurrencyFormatter {
        let formatter = CurrencyFormatter()
        formatter.setCode(to: scope.currency)
        formatter.setMinimumFractionDigits(specs.fractionalTrailingZeroDigits)
        if let symbol = specs.altUnitNames?[0] {
            formatter.setSymbol(to: symbol)
            formatter.hasAltUnitName0 = true
        }
        return formatter
    }

    public override init() {
        self.hasAltUnitName0 = false
        super.init()
        self.locale = Locale.current
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
    }

    func setUseSymbol(_ useSymbol: Bool) {
        numberStyle = useSymbol ? .currency : .currencyISOCode
    }

    func setCode(to code:String) {
        currencyCode = code
    }

    func setSymbol(to symbol:String) {
        currencySymbol = symbol
    }

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
