//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL

/// Ergebnis-Werte des compose-abort-Ruecksprungs (Vertrag Abschnitt 9,
/// docs/cross-platform/link-protokoll.md). Die Werte sind Protokoll -
/// keine weiteren erfinden.
enum AbortOutcome {
    /// Abbruch erfolgreich angestossen (Zustand aborting/aborted).
    static let aborted = "aborted"
    /// Empfaenger hat bereits eingelöst (Zustand done).
    static let alreadyClaimed = "already_claimed"
    /// Transaktion ist abgelaufen.
    static let expired = "expired"
    /// Nutzer hat abgelehnt bzw. den Dialog ohne Entscheidung geschlossen.
    static let declined = "declined"
    /// Die URI gehoert keiner eigenen Transaktion dieser Wallet
    /// (Multi-URI-Link, spec-multi-uri-link.md 3.3).
    static let notOwn = "not_own"
    /// Abbruch technisch gescheitert, URI ungueltig oder ueber der
    /// Obergrenze von 32 URIs (Multi-URI-Link).
    static let failed = "failed"

    /// Reines Mapping von wallet-core-Zustand und Abbruch-Erfolg auf das
    /// Protokoll-Ergebnis einer URI (Paket T5):
    /// - Abbruch erfolgreich -> `aborted` (unabhaengig vom Zustand).
    /// - Zustand aborting/aborted (zuvor bereits abgebrochen) -> `aborted`.
    /// - Zustand done -> `already_claimed`.
    /// - Zustand expired -> `expired`.
    /// - Keine eigene Transaktion -> `not_own`.
    /// - Abbruch fehlgeschlagen bei noch offenem Zustand -> `failed`.
    /// - Nicht versucht bei unbekanntem Zustand -> `declined`.
    ///   Keines davon aendert in Signal einen Status, Signal fragt nur den
    ///   echten Zustand ab.
    ///
    /// Parameter:
    /// - `majorState`: Zustand der Transaktion vor dem Abbruchversuch
    ///   (nil = keine eigene Transaktion gefunden oder nicht geladen).
    /// - `abortSucceeded`: true = abortTransaction lief ohne Fehler,
    ///   false = Abbruchversuch fehlgeschlagen, nil = nicht versucht.
    static func outcome(for majorState: TransactionMajorState?, abortSucceeded: Bool?) -> String {
        if abortSucceeded == true { return aborted }
        guard let majorState else { return abortSucceeded == false ? failed : notOwn }
        switch majorState {
            case .aborting, .aborted:
                return aborted
            case .done:
                return alreadyClaimed
            case .expired:
                return expired
            default:
                return abortSucceeded == false ? failed : declined
        }
    }
}

#if DEBUG
extension AbortOutcome {

    /// Selbsttest-Faelle fuer das Mapping (kein Testlauf fuer taler-ios in
    /// diesem Slot - der Reviewer fuehrt sie aus, Muster: SignalLinkSelfCheck).
    /// Rueckgabe ist die Liste der fehlgeschlagenen Faelle (leer = alles ok).
    static func runSelfCheck() -> [String] {
        var failures: [String] = []
        func expect(_ name: String, _ condition: Bool) {
            if !condition { failures.append(name) }
        }

        // 1) Abbruch erfolgreich -> immer aborted, egal welcher Zustand.
        expect("abort ok + pending -> aborted",
               outcome(for: .pending, abortSucceeded: true) == aborted)
        expect("abort ok + nil -> aborted",
               outcome(for: nil, abortSucceeded: true) == aborted)
        expect("abort ok + done -> aborted",
               outcome(for: .done, abortSucceeded: true) == aborted)

        // 2) Bereits abgebrochen (zuvor in Taler) -> aborted, auch wenn der
        //    erneute Abbruch fehlschlaegt (nicht mehr abbrechbar).
        expect("zustand aborted, fehlgeschlagen -> aborted",
               outcome(for: .aborted, abortSucceeded: false) == aborted)
        expect("zustand aborting, nicht versucht -> aborted",
               outcome(for: .aborting, abortSucceeded: nil) == aborted)

        // 3) Empfaenger hat eingelöst -> already_claimed.
        expect("zustand done, nicht versucht -> already_claimed",
               outcome(for: .done, abortSucceeded: nil) == alreadyClaimed)
        expect("zustand done, fehlgeschlagen -> already_claimed",
               outcome(for: .done, abortSucceeded: false) == alreadyClaimed)

        // 4) Abgelaufen -> expired.
        expect("zustand expired, nicht versucht -> expired",
               outcome(for: .expired, abortSucceeded: nil) == expired)
        expect("zustand expired, fehlgeschlagen -> expired",
               outcome(for: .expired, abortSucceeded: false) == expired)

        // 5) Keine eigene Transaktion -> not_own.
        expect("keine Transaktion, nicht versucht -> not_own",
               outcome(for: nil, abortSucceeded: nil) == notOwn)

        // 6) Abbruch fehlgeschlagen bei noch offenem Zustand -> failed.
        expect("abort fehlgeschlagen + pending -> failed",
               outcome(for: .pending, abortSucceeded: false) == failed)
        expect("abort fehlgeschlagen, Zustand unbekannt -> failed",
               outcome(for: nil, abortSucceeded: false) == failed)

        // 7) Nicht abgedeckte Zustaende -> konservativ declined.
        for state in [TransactionMajorState.none, .dialog, .finalizing,
                      .suspended, .suspendedFinalizing, .suspendedAborting,
                      .failed, .deleted] {
            expect("zustand \(state.rawValue) -> declined",
                   outcome(for: state, abortSucceeded: nil) == declined)
        }

        // 8) Protokoll-Werte, exakte Schreibweise.
        expect("Wert aborted exakt", aborted == "aborted")
        expect("Wert already_claimed exakt", alreadyClaimed == "already_claimed")
        expect("Wert expired exakt", expired == "expired")
        expect("Wert declined exakt", declined == "declined")
        expect("Wert not_own exakt", notOwn == "not_own")
        expect("Wert failed exakt", failed == "failed")

        return failures
    }
}
#endif

#endif
