//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import os.log

#if TALER_SIGNAL

/// Zentrale Annahmestelle für talerlink://-Links (Vertrag Abschnitt 2.1:
/// iOS schickt Signal ALLES über talerlink://). Hält den offenen
/// compose-*-Request für die UI (Platzhalter bis T2-T5) und den
/// Rücksprung-Kontext je peer-URI, damit T2 nach Annehmen/Bezahlen
/// zurückspringen kann.
///
/// Alle Methoden laufen auf dem Main-Thread (onOpenURL bzw. SwiftUI).
final class SignalLinkRouter: ObservableObject {
    static let shared = SignalLinkRouter()

    /// Offener compose-*-Request; nil = keiner anstehend. Ein neuer Link
    /// ersetzt den bisherigen ohne Rücksprung (Vertrag Abschnitt 3).
    @Published var pending: SignalLinkRequest? = nil

    /// Eigene, per talerlink://pay-* angesprochene Zahlung; nil = keine.
    /// MainView zeigt dafür das Detail-Sheet mit Abbrechen-Möglichkeit (T2)
    /// statt des Annehmen-Sheets. Wird beim Schließen des Sheets geleert.
    @Published var ownPayment: SignalOwnPaymentInfo? = nil

    /// Rücksprung-Kontext je bereinigter taler://-URI (peerAction).
    /// Wird nach einmaligem Verbrauch entfernt - single-use.
    private var peerContexts: [String: SignalReturnContext] = [:]

    /// Die taler://-URI des zuletzt gerouteten peer-Vorgangs. Dafür feuert
    /// beim Schließen ohne Abschluss das cancelled (T2) - nach ready ist der
    /// Kontext bereits verbraucht und es folgt kein zweiter Rücksprung.
    private var activePeerUri: URL? = nil

    private let logger = Logger(subsystem: "net.taler.gnu", category: "SignalLink")

    private init() { }

    /// Verarbeitet einen hereinkommenden talerlink://-Link.
    /// peerAction: Kontext merken und die bereinigte taler://-URI über den
    /// normalen Pfad weiterreichen (gleicher Weg wie beim QR-Scanner:
    /// controller.talerURI -> URLSheet -> urlCommand) - nie die
    /// talerlink-URL selbst. Gehört die URI zu einer EIGENEN Zahlung,
    /// wird stattdessen deren Detail-Sheet geöffnet (T2, Vertrag Abschnitt 6).
    /// compose-*: pending setzen; die UI zeigt das Sheet. Rückgabe true, wenn
    /// ein gültiger Request erkannt wurde.
    /// Es wird nie die URL geloggt, höchstens Host bzw. Art (Inhaberpapier).
    @MainActor
    func handle(_ url: URL) -> Bool {
        guard let request = SignalLinkRequest.parse(url) else {
            logger.notice("talerlink-Link ungültig - still verworfen")
            return false
        }
        switch request {
            case .peerAction(let talerUri, let ctx):
                logger.notice("talerlink peerAction übernommen")
                peerContexts[talerUri.absoluteString] = ctx
                activePeerUri = talerUri
                // Eigene URI? Erst wallet-core abwarten (Kaltstart über Link),
                // dann die Transaktionen durchsuchen. Bei Treffer Detail-Sheet,
                // sonst bereinigte taler://-URI an die bestehende Verarbeitung.
                Task { @MainActor in
                    await SignalLinkBackendGate.awaitBackendReady(Controller.shared)
                    if let transactionId = await findOwnPeerTransaction(
                                            forTalerUri: talerUri.absoluteString,
                                                       model: WalletModel.shared) {
                        logger.notice("eigene Zahlung erkannt - Detail statt Annehmen")
                        ownPayment = SignalOwnPaymentInfo(transactionId: transactionId,
                                                        talerUri: talerUri)
                    } else {
                        Controller.shared.talerURI = talerUri
                    }
                }
            case .composeSend:
                logger.notice("talerlink compose-send übernommen")
                pending = request
            case .composeRefund:
                logger.notice("talerlink compose-refund übernommen")
                pending = request
            case .composeAbort:
                logger.notice("talerlink compose-abort übernommen")
                pending = request
        }
        return true
    }

    /// Rücksprung-Kontext für eine bereinigte taler://-URI, falls der Link
    /// von Signal kam (sonst nil - QR-Code, Web-Link, fremde Quelle).
    @MainActor
    func context(forTalerUri uri: String) -> SignalReturnContext? {
        peerContexts[uri]
    }

    /// Wie context(forTalerUri:), entfernt den Eintrag danach (single-use).
    @MainActor
    func consumeContext(forTalerUri uri: String) -> SignalReturnContext? {
        defer { peerContexts[uri] = nil }
        return peerContexts[uri]
    }

    /// Rücksprung cancelled für den gerade offenen peer-Vorgang, falls noch
    /// ein Kontext existiert (consume - nach einem ready bleibt nichts mehr,
    /// also folgt nie ein doppelter Rücksprung). Aufruf beim Schließen des
    /// Sheets ohne Abschluss. Räumt die aktive URI in jedem Fall ab.
    @MainActor
    func cancelActivePeer() {
        if let uri = activePeerUri {
            signalReturnCancelled(for: uri)
        }
        activePeerUri = nil
    }
}

#endif
