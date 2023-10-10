/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift

public class CurrencyFormatter: NumberFormatter {
    public static let shared = CurrencyFormatter()

    public override init() {
        super.init()
        self.locale = Locale.current
        self.numberStyle = .currency            // currencyISOCode, currencyPlural, (currencyAccounting)
        self.numberStyle = .currencyISOCode
//        self.numberStyle = .spellOut

//        self.currencyCode = code              // EUR, USD, JPY, GBP
//        self.minimumFractionDigits = fractionDigits
//        self.maximumFractionDigits = fractionDigits
//        self.groupingSize = 3                 // thousands
//        self.groupingSeparator = ","
//        self.usesGroupingSeparator = true
//        self.decimalSeparator = "."
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
