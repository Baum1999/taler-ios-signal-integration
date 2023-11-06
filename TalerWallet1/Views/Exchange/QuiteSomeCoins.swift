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

    let fee: String
    var hasFee:    Bool { fee.count > 0 }
}

extension SomeCoins {
    init(details: WithdrawalAmountDetails?) {
        do {
            if let details {
                // Incoming: fee = raw - effective
                let fee = try details.amountRaw - details.amountEffective
                self.init(numCoins: details.numCoins ?? -1,    // either the number of coins, or unknown
                               fee: fee.isZero ? "" : fee.readableDescription)
                return
            }
        } catch {}
        self.init(numCoins: 0, fee:"")      // invalid
    }

    init(details: CheckPeerPullCreditResponse?) {
        do {
            if let details {
                // Incoming: fee = raw - effective
                let fee = try details.amountRaw - details.amountEffective
                self.init(numCoins: details.numCoins ?? -1,    // either the number of coins, or unknown
                               fee: fee.isZero ? "" : fee.readableDescription)
                return
            }
        } catch {}
        self.init(numCoins: 0, fee:"")      // invalid
    }
}
// MARK: -
struct QuiteSomeCoins: View {
    private let symLog = SymLogV(0)
    let someCoins: SomeCoins
    let shouldShowFee: Bool
    let currency: String
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
            Text(someCoins.invalid ? "Amount too small!"
               : someCoins.tooMany ? "Amount too big for a single withdrawal!"
                : someCoins.hasFee ? "- \(someCoins.fee) fee"
                                   : "No withdrawal fee")
            .foregroundColor((someCoins.invalid || someCoins.tooMany || someCoins.hasFee) ? .red : .primary)
            .accessibilityFont(.body)
//            .padding(4)
        }
    }
}
// MARK: -
struct QuiteSomeCoins_Previews: PreviewProvider {
    static var previews: some View {
        QuiteSomeCoins(someCoins: SomeCoins(numCoins: 4, fee: "20 " + LONGCURRENCY),
                   shouldShowFee: true,
                        currency: LONGCURRENCY,
                 amountEffective: nil)
    }
}
