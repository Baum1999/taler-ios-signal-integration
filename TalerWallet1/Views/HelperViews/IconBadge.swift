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
        let imageName = incoming && done ? DONE_INCOMING
                                         : incoming ? PENDING_INCOMING
                                        // since the money already left the wallet, show DONE
                                         : DONE_OUTGOING        // PENDING_OUTGOING
        IconBadge(imageName: imageName,
                  isPending: true,
                  foreColor: foreColor,
              shouldConfirm: shouldConfirm,
                   needsKYC: needsKYC,
               wideIconName: nil)
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
        let imageName = type.iconName(done)
        IconBadge(imageName: imageName,
                  isPending: false,
                  foreColor: foreColor,
              shouldConfirm: shouldConfirm,
                   needsKYC: needsKYC,
               wideIconName: nil)
    }
}
// MARK: -
struct ButtonIconBadge: View {
    var type: TransactionType
    let foreColor:Color
    let done: Bool

    var body: some View {
        let imageName = type.iconName(done)
        IconBadge(imageName: imageName,
                  isPending: false,
                  foreColor: foreColor,
              shouldConfirm: false,
                   needsKYC: false,
               wideIconName: ICONNAME_INCOMING_P2P)
    }
}
// MARK: -
struct IconBadge: View {
    let imageName: String
    let isPending: Bool
    let foreColor:Color
//    let pending: Bool
    let shouldConfirm: Bool
    let needsKYC: Bool
    let wideIconName: String?

    var body: some View {
        HStack(alignment: .top, spacing: -8) {      // TODO: adapt spacing to dynamic fontsize
            let image = isPending ? Image(systemName: imageName)
                                  : Image(imageName)
            ZStack {
                // "taler.turn.up.backward" is wider than all others
                // ZStack centers the main icon, and the badge will always be at the same position
                Image(wideIconName ?? ICONNAME_REFUND)
                    .foregroundColor(.clear)
                image
                    .foregroundColor(foreColor)
            }.talerFont(.title)
            if wideIconName == nil {
                let badgeName = needsKYC ? NEEDS_KYC
                                         : CONFIRM_BANK
                Image(systemName: badgeName)
                    .talerFont(.caption)
                    .foregroundColor((needsKYC || shouldConfirm) ? .red : .clear)
            }
        }.accessibilityHidden(true)
    }
}
// MARK: -
//#Preview {
//    IconBadge()
//}
