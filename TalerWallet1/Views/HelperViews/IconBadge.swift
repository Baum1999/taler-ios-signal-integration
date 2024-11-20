/*
 * This file is part of GNU Taler, ©2022-24 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct PendingIconBadge: View {
    let foreColor:Color
    let done: Bool
    let incoming: Bool
    let shouldConfirm: Bool
    let needsKYC: Bool

    var body: some View {
        let image = incoming && done ? Image(systemName: DONE_INCOMING)         // "plus.circle.fill"
                          : incoming ? Image(systemName: PENDING_INCOMING)      // "plus"
        // since outgoing money already left the wallet, show DONE_ and not PENDING_OUTGOING
                                     : Image(systemName: DONE_OUTGOING)         // "minus.circle"
        IconBadge(image: image,
                   done: false,
              foreColor: foreColor,
          shouldConfirm: shouldConfirm,
               needsKYC: needsKYC,
               wideIcon: nil)
    }
}
// MARK: -
struct TransactionIconBadge: View {
    var type: TransactionType
    let foreColor:Color
    let done: Bool
    let incoming: Bool
    let shouldConfirm: Bool
    let needsKYC: Bool

    var body: some View {
        IconBadge(image: type.icon(done),
                   done: true,
              foreColor: foreColor,
          shouldConfirm: shouldConfirm,
               needsKYC: needsKYC,
               wideIcon: TransactionType.refund.icon())
                      // "arrowshape.turn.up.backward" is wider than all others
    }
}
// MARK: -
struct ButtonIconBadge: View {
    var type: TransactionType
    let foreColor:Color
    let done: Bool

    var body: some View {
        IconBadge(image: type.icon(done),
                   done: true,
              foreColor: foreColor,
          shouldConfirm: false,
               needsKYC: false,
               wideIcon: TransactionType.peerPushDebit.icon())
                      // button is send/receive/withdraw/deposit, never payment or refund
    }
}
// MARK: -
struct IconBadge: View {
    let image: Image
    let done: Bool
    let foreColor:Color
    let shouldConfirm: Bool
    let needsKYC: Bool
    let wideIcon: Image?        // cheating: ZStack with widest icon to ensure all have the same width
                                // TODO: EqualIconWidth...

    @ScaledMetric var spacing = 8       // relative to fontSize

    var body: some View {
        HStack(alignment: .top, spacing: -spacing) {
            ZStack {
                if let wideIcon {
                    wideIcon.foregroundColor(.clear)
                }
                image.foregroundColor(foreColor)
            }.talerFont(.title2)
            if wideIcon == nil {
                // ZStack centers the main icon, so the badge will always be at the same position
                let badgeName = needsKYC ? NEEDS_KYC
                                         : CONFIRM_BANK
                Image(systemName: badgeName)
                    .talerFont(.caption)
                    .foregroundColor(needsKYC ? WalletColors().attention
                              : shouldConfirm ? WalletColors().confirm
                                              : .clear)
            }
        }.accessibilityHidden(true)
    }
}
// MARK: -
//#Preview {
//    IconBadge()
//}
