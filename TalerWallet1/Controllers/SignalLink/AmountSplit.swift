//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL

/// Aufteilung eines Gesamtbetrags auf N Personen für den Gruppen-Split
/// (Paket T3, Android-Gegenstück: link/AmountSplit.kt).
enum AmountSplit {

    /// Anteil pro Person: immer abgerundet (FLOOR) auf 8 Nachkommastellen,
    /// sodass die Summe der Anteile den Gesamtbetrag nie übersteigt
    /// (Android: BigDecimal.divide(scale 8, RoundingMode.FLOOR)). Die 8
    /// Stellen entsprechen Taler (Amount.fractionalBaseDigits = 8).
    /// Rückgabe nil bei parts < 1 oder total <= 0.
    static func splitAmountEvenly(total: Decimal, parts: Int) -> Decimal? {
        guard parts >= 1, total > 0 else { return nil }
        // Division mit voller Decimal-Genauigkeit (Swifts '/' rechnet intern
        // mit bis zu 38 Stellen - für Beträge aus Amount, maximal 2^52 plus
        // 8 Nachkommastellen, verlustfrei), danach einmalig auf 8 Stellen
        // abrunden: mit 10^8 multiplizieren, Richtung -unendlich runden,
        // zurückschneiden. Der Anteil ist immer >= 0, daher ist Abrunden
        // Richtung 0 hier identisch mit FLOOR.
        let quotient = total / Decimal(parts)
        var scaledInput = quotient * Decimal(100_000_000)
        var scaledResult = Decimal()
        NSDecimalRound(&scaledResult, &scaledInput, 0, .down)
        return scaledResult / Decimal(100_000_000)
    }
}

#endif
