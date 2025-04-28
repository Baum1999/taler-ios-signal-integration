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
    let isFinal: Bool
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
        .tagStyle(isFinal ? .prominent : .borderless)
        .opacity(enabled ? 1.0 : 0.01)
        .disabled(!enabled)
    }
}

struct OIMbalanceButton: View {
    let isOpen: Bool
    let isSierra: Bool
    let isFinal: Bool
    let action: () -> Void

    var body: some View {
        let imageName = isSierra ? (isOpen ? "ChestSLopen" : "ChestSLclosed")
//                                 : (isOpen ? "ChestDEopen" : "ChestDEclosed")
//                                 : (isOpen ? "ChestEUopen" : "ChestEUclosed")
                                 : (isOpen ? "ChestEUopen1" : "ChestEUclosed1")
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
        }
        .tagStyle(isFinal ? .prominent : .borderless)
    }
}

enum TagButtonStyle {
    case prominent
    case bordered
    case `default`
    case borderless
    // .. extend with any custom here
}

extension Button {

    @ViewBuilder
    func tagStyle(_ style: TagButtonStyle) -> some View {
        switch style {
            case .prominent:
                self.buttonStyle(BorderedProminentButtonStyle())
            case .bordered:
                self.buttonStyle(BorderedButtonStyle())
            case .borderless:
                self.buttonStyle(BorderlessButtonStyle())
            case .default:
                self.buttonStyle(DefaultButtonStyle())
                // .. extend with any custom here
        }
    }
}

