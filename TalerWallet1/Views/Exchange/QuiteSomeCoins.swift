/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog

struct SomeCoins {
    let numCoins: Int       // 0 == invalid, -1 == unknown
    var unknown:   Bool { numCoins < 0 }
    var invalid:   Bool { numCoins == 0 }
    var manyCoins: Bool { numCoins > 99 }
    var quiteSome: Bool { numCoins > 199 }
    var tooMany:   Bool { numCoins > 999 }

    let fee: Amount?
}

extension SomeCoins {
    init(details: WithdrawalAmountDetails?) {
        do {
            if let details {
                // Incoming: fee = raw - effective
                let aFee = try details.amountRaw - details.amountEffective
                self.init(numCoins: details.numCoins ?? -1,    // either the number of coins, or unknown
                               fee: aFee)
                return
            }
        } catch {}
        self.init(numCoins: 0, fee: nil)      // invalid
    }

    init(details: CheckPeerPullCreditResponse?) {
        do {
            if let details {
                // Incoming: fee = raw - effective
                let aFee = try details.amountRaw - details.amountEffective
                self.init(numCoins: details.numCoins ?? -1,    // either the number of coins, or unknown
                               fee: aFee)
                return
            }
        } catch {}
        self.init(numCoins: 0, fee: nil)      // invalid
    }
}
// MARK: -
struct QuiteSomeCoins: View {
    private let symLog = SymLogV(0)
    let someCoins: SomeCoins
    let shouldShowFee: Bool
    let currency: String
    let currencyInfo: CurrencyInfo?
    let amountEffective: Amount?

    var body: some View {
        if !someCoins.invalid {
            if !someCoins.tooMany {
                if someCoins.manyCoins {
                    Text(someCoins.quiteSome ? "Note: It will take quite some time to withdraw this amount! Be more patient..."
                                             : "Note: It will take some time to withdraw this amount. Be patient...")
                    .foregroundColor(someCoins.quiteSome ? .red : .primary)
                    .accessibilityFont(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 6)
                } // warnings
            }
        }
        if shouldShowFee {
            if let fee = someCoins.fee {
                Text(someCoins.invalid ? "Amount too small!"
                   : someCoins.tooMany ? "Amount too big for a single withdrawal!"
                          : fee.isZero ? "No withdrawal fee"
                                       : "- \(fee.string(currencyInfo)) fee")
                .foregroundColor((someCoins.invalid || someCoins.tooMany || !fee.isZero) ? .red : .primary)
                .accessibilityFont(.body)
            }
        }
    }
}
// MARK: -
struct QuiteSomeCoins_Previews: PreviewProvider {
    static var previews: some View {
        QuiteSomeCoins(someCoins: SomeCoins(numCoins: 4, fee: Amount(currency: LONGCURRENCY, cent: 20) ),
                   shouldShowFee: true,
                        currency: LONGCURRENCY,
                    currencyInfo: nil,
                 amountEffective: nil)
    }
}
