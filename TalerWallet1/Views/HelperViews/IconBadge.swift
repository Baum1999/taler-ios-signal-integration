/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
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
                  phase: 0,
             firstImage: nil,
            secondImage: nil,
               wideIcon: nil)
    }
}
// MARK: -
struct TransactionIconBadge: View {
    var type: TransactionType
    var foreColor: Color
    let done: Bool
    let incoming: Bool
    let shouldConfirm: Bool
    let needsKYC: Bool

    init(type: TransactionType, foreColor: Color, done: Bool, incoming: Bool, shouldConfirm: Bool, needsKYC: Bool) {
        self.type = type
        self.foreColor = foreColor
        self.done = done
        self.incoming = incoming
        self.shouldConfirm = shouldConfirm
        self.needsKYC = needsKYC
    }

    init(from transaction: TalerTransaction, isDark: Bool, _ increasedContrast: Bool) {
        let common = transaction.common
        self.type = common.type
        let done = transaction.isDone
        self.done = done
        let incoming = common.isIncoming
        self.incoming = incoming
        let needsKYC = transaction.isPendingKYC || transaction.isPendingKYCauth
        self.needsKYC = needsKYC
        self.shouldConfirm = transaction.shouldConfirm
        let pending = transaction.isPending || transaction.common.isFinalizing
        self.foreColor = .primary

        let doneOrPending = done || pending
        let isZero = common.amountEffective.isZero
        let refreshZero = common.type.isRefresh && isZero
        let textColor = doneOrPending ? .primary
                             : isDark ? .secondary
                  : increasedContrast ? Color(.darkGray)
                                      : .secondary  // Color(.tertiaryLabel)
        let foreColor = refreshZero ? textColor
                          : pending ? WalletColors().pendingColor(incoming)
                             : done ? WalletColors().transactionColor(incoming)
                                    : WalletColors().uncompletedColor
        self.foreColor = foreColor
    }

    var body: some View {
        IconBadge(image: type.icon(done),
                   done: true,
              foreColor: foreColor,
          shouldConfirm: shouldConfirm,
               needsKYC: needsKYC,
                  phase: 0,
             firstImage: nil,
            secondImage: nil,
               wideIcon: TransactionType.refund.icon())
                      // "arrowshape.turn.up.backward" is wider than all others
    }
}
// MARK: -
struct ButtonIconBadge: View {
    let type: TransactionType
    let phase: Int
    let foreColor:Color
    let done: Bool

    var body: some View {
        let isSend = type.isSendCoins
        let isRcve = type.isSendInvoice
        let isDepo = type.isDeposit
        let isWthd = type.isWithdrawal
        let left = ICONNAME_PERSON_LEFT + ICONNAME_FILL
        let right = ICONNAME_PERSON_RIGHT
        let bottom = ICONNAME_PERSON_BOTTOM + ICONNAME_FILL
        let top = ICONNAME_BANK
        let firstImage = isSend ? Image(left)
                       : isRcve ? Image(right)
                       : isDepo ? Image(bottom)
                       : isWthd ? Image(top) : nil
        let secondImage = isSend ? Image(right)
                        : isRcve ? Image(left)
                        : isDepo ? Image(top)
                        : isWthd ? Image(bottom) : nil
        IconBadge(image: type.icon(done),
                   done: true,
              foreColor: foreColor,
          shouldConfirm: false,
               needsKYC: false,
                  phase: phase,
             firstImage: firstImage,
            secondImage: secondImage,
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
    let phase: Int
    let firstImage: Image?
    let secondImage: Image?
    let wideIcon: Image?        // cheating: ZStack with widest icon to ensure all have the same width
                                // TODO: EqualIconWidth...

    @ScaledMetric var spacing = 6       // relative to fontSize
    @State private var showFirst = false
    @State private var showSecond = false
    @State private var showImage = true

    var body: some View {
//        let _ = Self._printChanges()
        HStack(alignment: .top, spacing: -spacing) {
            ZStack {
                if let wideIcon {
                    wideIcon.foregroundColor(.clear)
                }
                if let firstImage, let secondImage {
                    let duration = 0.66
                    ZStack {
                        image.opacity(showImage ? 1 : 0)
                            .animation(.easeInOut(duration: duration), value: showImage)
                        firstImage.opacity(showFirst ? 1 : 0)
                            .animation(.easeOut(duration: duration), value: showFirst)
                        secondImage.opacity(showSecond ? 1 : 0)
                            .animation(.easeIn(duration: duration), value: showSecond)
                    }   .foregroundColor(foreColor)
                        .onChange(of: phase) { phaseVal in
                            switch phaseVal {
                                case 0, 4: showFirst = false; showSecond = false; showImage = true
                                case 2, 3: showFirst = true; showSecond = false; showImage = false
                                case 5, 6: showFirst = false; showSecond = true; showImage = false
                                default: showFirst = false; showSecond = false; showImage = false
                            }
                        }
                } else {
                    image.foregroundColor(foreColor)
                }
            }
            // ZStack centers the main icon, so the badge will always be at the same position
            let badgeName = needsKYC ? NEEDS_KYC
                                     : CONFIRM_BANK
            Image(systemName: badgeName)
                .talerFont(.badge)
                .foregroundColor(needsKYC ? WalletColors().attention
                          : shouldConfirm ? WalletColors().confirm
                                          : .clear)
                .padding(.top, -2)
        }.accessibilityHidden(true)
    }
}
// MARK: -
//#Preview {
//    IconBadge()
//}
