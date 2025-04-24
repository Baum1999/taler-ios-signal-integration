/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI

struct OIMsendButton: View {
    let isGoal: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        let imageName = isGoal ? "noun-football-goal-4935574"
                               : "SendTaler"
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
//                .tint(WalletColors().talerColor)
                .foregroundStyle(WalletColors().talerColor)
        }
        .opacity(enabled ? 1.0 : 0.3)
        .disabled(!enabled)
    }
}

struct OIMbalanceButton: View {
    let isOpen: Bool
    let tint: Bool
    let action: () -> Void

    var body: some View {
        let imageName = isOpen ? "ChestOpen" : "ChestClosed"
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint ? .brown
                                      : WalletColors().talerColor)
        }
    }
}

