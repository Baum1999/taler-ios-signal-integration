/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import taler_swift

public class CurrencyFormatter: NumberFormatter {
    public static var shared = CurrencyFormatter()

    private override convenience init() {
        self.init(fractionDigits: 2)
    }

    public init(fractionDigits: Int) {
        super.init()
        self.numberStyle = .decimal // currency could be changed by user
        self.minimumFractionDigits = fractionDigits
        self.maximumFractionDigits = fractionDigits
        self.usesGroupingSeparator = true
        self.locale = Locale.current
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
