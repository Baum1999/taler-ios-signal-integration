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
    func feeLabel(_ currencyInfo: CurrencyInfo?) -> String {
       return if let fee {
                invalid ? String(localized: "Amount too small!")
              : tooMany ? String(localized: "Amount too big for a single withdrawal!")
           : fee.isZero ? String(localized: "No withdrawal fee")
                        : String(localized: "- \(fee.formatted(currencyInfo, isNegative: false)) fee")
       } else {
           EMPTYSTRING
       }
    }
}

extension CoinData {
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
    @Binding var currencyInfo: CurrencyInfo
    let currency: String
    let coinData: CoinData
    let shouldShowFee: Bool
    let amountEffective: Amount?

    var body: some View {
        if !coinData.invalid {
            if !coinData.tooMany {
                if coinData.manyCoins {
                    Text(coinData.quiteSome ? "Note: It will take quite some time to withdraw this amount! Be more patient..."
                                             : "Note: It will take some time to withdraw this amount. Be patient...")
                    .foregroundColor(coinData.quiteSome ? .red : .primary)
                    .talerFont(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 6)
                } // warnings
            }
        }
        if shouldShowFee {
            if let fee = coinData.fee {
                Text(coinData.feeLabel(currencyInfo))
                    .foregroundColor((coinData.invalid || coinData.tooMany || !fee.isZero) ? .red : .primary)
                    .talerFont(.body)
            }
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
