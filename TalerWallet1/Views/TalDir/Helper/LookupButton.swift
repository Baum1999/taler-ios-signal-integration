/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift

// MARK: -
enum LookupState {
    case unknown            // not yet asked
    case error              // (Error)
    case unregistered       //
    case registered(String, Duration) // we just (un)registered it, but it isn't confirmed yet
    case confirmed(String, Duration)  // lookup result

    var hasTarget: Bool {
        switch self {
            case .registered, .confirmed:
                return true
            default:
                return false
        }
    }
}
// MARK: -
struct LookupButton: View {
    let stack: CallStack
    let alias: String
    let aliasType: TaldirAliasType
    @Binding var lookupState: LookupState
//    @FocusState.Binding var isFocused: Bool
    let focus: () -> Void
    let action: () -> Void

    @EnvironmentObject private var model: WalletModel
    @State private var working: Bool = false

    var body: some View {
        let buttonTitle = String(localized: "Lookup Alias", comment: "button")
        FeedbackButton(buttonTitle, disabled: working, haptic: false) {
            working = true
            focus()             // isFocused = false    // dismiss keyboard
            let lookup = TaldirLookup(alias: alias,
                                  aliasType: aliasType.name)
            Task {
                let lookup = try? await model.lookupAlias(lookup)
                if let targetUri = lookup?.targetUri {
                    if targetUri.isEmpty {
                        lookupState = .unregistered
                    } else {
                        let validFor = lookup?.validFor
                        lookupState = .confirmed(targetUri, validFor ?? Duration.microseconds(0))
                    }
                } else {
                    lookupState = .error
                }
                self.working = false
                action()
            }
        }
    }
}
