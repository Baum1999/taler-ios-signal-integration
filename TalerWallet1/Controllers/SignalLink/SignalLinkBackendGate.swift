//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL

/// Hilfsstelle für den Kaltstart über einen talerlink://-Link: wallet-core
/// ist evtl. noch nicht initialisiert, wenn der Link ankommt (Vertrag
/// Abschnitt 3: "backendState == .ready abwarten"). UI-Code, der Beträge
/// verarbeitet, wartet zuerst hier.
enum SignalLinkBackendGate {
    /// Wartet, bis das Backend bereit ist. Beendet auch bei Backend-Fehler
    /// (dann wird es nie ready) sowie bei Task-Abbruch; der Aufrufer
    /// behandelt diesen Fall wie seinen normalen Fehlerfall.
    @MainActor
    static func awaitBackendReady(_ controller: Controller) async {
        while controller.backendState != .ready {
            if case .error = controller.backendState { return }
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 100_000_000)      // 100 ms
        }
    }
}

#endif
