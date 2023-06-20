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
    init(details: ManualWithdrawalDetails?) {
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
    private let symLog = SymLogV()
    let someCoins: SomeCoins
    let shouldShowFee: Bool
    let currency: String
    let amountEffective: Amount?

    var body: some View {
        if shouldShowFee {
            let shownFee = someCoins.hasFee ? String(localized: "- \(someCoins.fee)")
                                            : String(localized: "No")
            Text(someCoins.invalid ? "invalid amount"
               : someCoins.tooMany ? "too many coins for a single withdrawal"
                                   : "\(shownFee) withdrawal fee")
            .foregroundColor((someCoins.invalid || someCoins.tooMany || someCoins.hasFee) ? .red : .primary)
            .padding(4)
        }
        if !someCoins.invalid {
            HStack {
                Text(someCoins.unknown ? "Some" : "\(someCoins.numCoins)")
                    .foregroundColor(someCoins.quiteSome ? .red : .primary)
                Text(someCoins.tooMany ? "coins" : "coins to obtain:")
                    .foregroundColor(someCoins.tooMany ? .red : .primary)

                Spacer()
                if !someCoins.tooMany {
                    let effective = amountEffective ?? Amount(currency: currency, value: 0)
                    Text(effective.readableDescription)
                }
            } // xx coins to obtain:    YYY currency
//            .font(.title3)
            .padding(.top)

            if !someCoins.tooMany {
                if someCoins.manyCoins {
                    Text(someCoins.quiteSome ? "Warning: It will take quite some time\nto generate this many coins!"
                                             : "Warning: It will take some time\nto generate this many coins.")
                    .multilineTextAlignment(.leading)
                    .padding(.top, 6)
                    .foregroundColor(someCoins.quiteSome ? .red : .primary)
                } // warnings
            }
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
