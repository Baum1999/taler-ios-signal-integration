/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

struct CoinData {
    let numCoins: Int       // 0 == invalid, -1 == unknown
    var unknown:   Bool { numCoins < 0 }
    var invalid:   Bool { numCoins == 0 }
    var manyCoins: Bool { numCoins > 99 }
    var quiteSome: Bool { numCoins > 199 }
    var tooMany:   Bool { numCoins > 999 }

    let fee: Amount?
    func feeLabel(_ scope: ScopeInfo?, feeZero: String?, isNegative: Bool = false) -> String {
       return if let fee {
           fee.isZero ? feeZero ?? EMPTYSTRING    // String(localized: "No withdrawal fee")
         : isNegative ? String(localized: "- \(fee.formatted(scope, isNegative: false)) fee")
                      : String(localized: "+ \(fee.formatted(scope, isNegative: false)) fee")
       } else {
           EMPTYSTRING
       }
    }
}

extension CoinData {
    init(coins numCoins: Int?, fee: Amount?) {
        self.init(numCoins: numCoins ?? -1, fee: fee)           // either the number of coins, or unknown
    }

    init(details: WithdrawalDetailsForAmount?) {
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
    let scope: ScopeInfo?
    let coinData: CoinData
    let shouldShowFee: Bool
    let feeIsNegative: Bool

    var body: some View {
        let isError = coinData.tooMany // || coinData.invalid
        let showFee = shouldShowFee && !isError
        if showFee {
            if let fee = coinData.fee {
                Text(coinData.feeLabel(scope, feeZero: String(localized: "No withdrawal fee"),
                                       isNegative: feeIsNegative))
                .foregroundColor(.primary)
                .talerFont(.body)
            }
        }
        if isError || coinData.quiteSome || coinData.manyCoins {
            Text(coinData.tooMany ? "Amount too big for a single withdrawal!"
             : coinData.quiteSome ? "Note: It will take quite some time to prepare this amount! Be more patient..."
                                  : "Note: It will take some time to prepare this amount. Be patient...")
                .foregroundColor(isError || coinData.quiteSome ? .red : .primary)
                .talerFont(.body)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 6)
        }
    }
}
// MARK: -
//struct QuiteSomeCoins_Previews: PreviewProvider {
//    static var previews: some View {
//        QuiteSomeCoins(coinData: CoinData(numCoins: 4, fee: Amount(currency: LONGCURRENCY, cent: 20) ),
//                  shouldShowFee: true,
//                amountEffective: nil)
//    }
//}
