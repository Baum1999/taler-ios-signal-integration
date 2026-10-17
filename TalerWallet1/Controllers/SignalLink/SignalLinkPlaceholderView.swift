//
// Signal integration.
// SPDX-License-Identifier: AGPL-3.0-only
//

import SwiftUI

#if TALER_SIGNAL

/// Platzhalter-Sheet für talerlink://compose-send/-refund/-abort, bis die
/// echten Screens aus T2-T5 folgen. "Zurück zu Signal" meldet cancelled
/// zurück (Rücksprung ausschließlich über ReturnURLBuilder, Vertrag 2.5);
/// "Schließen" beendet ohne Rücksprung.
struct SignalLinkPlaceholderView: View {
    /// Der anstehende compose-*-Request (peerAction zeigt kein Sheet).
    let request: SignalLinkRequest

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Noch nicht verfügbar")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Diese Funktion steht in dieser Version noch nicht bereit.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    ReturnURLBuilder.open(ReturnURLBuilder.cancelled(ctx: request.ctx))
                    dismiss()
                } label: {
                    Text("Zurück zu Signal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    dismiss()
                } label: {
                    Text("Schließen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
    }
}

#endif
