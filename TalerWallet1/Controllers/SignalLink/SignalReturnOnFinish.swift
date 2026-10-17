//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

#if TALER_SIGNAL

/// Rücksprung zu Signal mit status=ready (Vertrag Abschnitt 8): holt den
/// Kontext zur taler://-URI und verbraucht ihn (genau EIN Rücksprung pro
/// Kontext - consume). Kein Kontext (QR-Code, Web-Link, fremde Quelle oder
/// bereits verbraucht) -> nichts tun, das ist der normale Taler-Link ohne
/// Signal-Beteiligung. Die URI wird nie geloggt (Inhaberpapier, Vertrag 2.6).
@MainActor
func signalReturnReady(for url: URL) {
    let uri = url.absoluteString
    guard let ctx = SignalLinkRouter.shared.consumeContext(forTalerUri: uri) else { return }
    ReturnURLBuilder.open(ReturnURLBuilder.ready(ctx: ctx, talerUri: uri, paymentDataJson: nil))
}

/// Rücksprung zu Signal mit status=cancelled (Vertrag Abschnitt 8): der Nutzer
/// hat ohne Abschluss geschlossen oder abgebrochen. talerUri und
/// talerPaymentData werden bewusst nicht mitgeschickt. Sonst wie ready.
@MainActor
func signalReturnCancelled(for url: URL) {
    let uri = url.absoluteString
    guard let ctx = SignalLinkRouter.shared.consumeContext(forTalerUri: uri) else { return }
    ReturnURLBuilder.open(ReturnURLBuilder.cancelled(ctx: ctx))
}

#endif
