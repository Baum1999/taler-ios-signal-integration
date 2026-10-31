/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

// MARK: -
/// This view shows the Alias registration          t15@fesh.com
struct AliasView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var working: Bool = false
    @State private var lookupState: LookupState = .unknown
    @State private var selectedType: Int = 0
    @State private var lastType: Int? = nil
    @State private var alias: String = EMPTYSTRING
    @State private var lastAlias: String = EMPTYSTRING
    @State private var challenge: String = EMPTYSTRING
    @State private var aliasTypes: [TaldirAliasType]? = nil
    @State private var validFor: Duration? = nil
    @State private var addContact: Bool = false
//    @ScaledMetric var frameHeight: CGFloat = 40          // relative to fontSize

    private enum FocusField { case alias, code }
    @FocusState private var focus: FocusField?

    @MainActor
    private func viewDidLoad() async {
        if aliasTypes == nil {
            if let types = try? await model.getSupportedAliasTypes() {
                aliasTypes = types
    }   }   }

    @ViewBuilder func registerButton(_ aliasType: TaldirAliasType,
                                   configuration: MailboxConfiguration) -> some View {
        let hasTarget = lookupState.hasTarget
        let title = hasTarget ? String(localized: "Unregister Alias", comment: "button")
                              : String(localized: "Register Alias", comment: "button")
        FeedbackButton(title, disabled: working, haptic: false) {
            working = true
            focus = nil    // dismiss keyboard
            let seconds: UInt64 = hasTarget ? 0 : 60*60*24*365      // 1 year
            let microSeconds = seconds * 1_000_000
            let targetUri = hasTarget ? EMPTYSTRING
                                      : configuration.hAddress
            let register = TaldirRegistration(alias: alias,
                                          aliasType: aliasType.name,
                                     mailboxAddress: targetUri,
                                           duration: Duration.microseconds(microSeconds))
            Task {
                do {
                    if let result = try await model.registerAlias(register) {
                        validFor = result
                    } else {
                        print("register succeeded, but did not return a validity period")
                    }
                    lookupState = .registered(targetUri, Duration.microseconds(0))
                } catch {    // it didn't succeed
                    // TODO: show error
                    print("register failed")
                    lookupState = .error
                }
                self.working = false
            }
        }
    }

    @ViewBuilder func confirmButton(_ aliasType: TaldirAliasType, _ targetUri: String) -> some View {
        let title = String(localized: "Confirm", comment: "button")
        FeedbackButton(title, disabled: working, haptic: false) {
            working = true
            focus = nil    // dismiss keyboard
            let register = TaldirRegistration(alias: alias,
                                          aliasType: aliasType.name,
                                     mailboxAddress: targetUri,
                                          challenge: challenge.uppercased())
            Task {
                do {
                    try await model.completeRegisterAlias(register)
                    challenge = EMPTYSTRING
                    lookupState = targetUri.isEmpty ? .unregistered
                                                    : .confirmed(targetUri, Duration.microseconds(0))
                } catch {    // it didn't succeed
                    // TODO: show error
                    print("confirm failed")
                    lookupState = .error
                }
                self.working = false
            }
        }
    }

    @ViewBuilder func addContactButton(_ aliasType: TaldirAliasType, address: String) -> some View {
        let buttonTitle = String(localized: "Add to Contacts", comment: "button")
        let contact = ContactEntry(alias: alias,
                               aliasType: aliasType.name,
                          mailboxAddress: address,
                                  isSelf: true)
        let destination = AddContactView(stack.push(), contact: contact)
        let actions = Group {
            NavLink($addContact) { destination }
        }
        FeedbackButton(buttonTitle, disabled: working, haptic: false) {
            focus = nil    // dismiss keyboard
            addContact = true
        }
            .background(actions)
    }

    @ViewBuilder func picker(_ aliasTypes: [TaldirAliasType]) -> some View {
        AliasPicker(stack: stack.push(),
                    title: String(localized: "Alias Type:", comment: "Picker title"),
                    value: $selectedType,
                    types: aliasTypes
        ) { selected in
            if selected != lastType {
                lookupState = .unknown
            }
        }
    }

    @ViewBuilder func codeInput() -> some View {
        StandardInput(stack: stack.push(),
                      label: String(localized: "Code:", comment: "TextEdit purpose, a11y"),
                placeHolder: EMPTYSTRING,
                       text: $challenge)
        .focused($focus, equals: .code)
        .onSubmit {
            focus = nil
            print("TODO: start confirmation")
        }
    }

    @ViewBuilder func lookupButton(_ aliasType: TaldirAliasType) -> some View {
        LookupButton(stack: stack.push(),
                     alias: alias,
                 aliasType: aliasType,
               lookupState: $lookupState,
                     focus: { focus = nil }
        ) {
            lastType = selectedType
            lastAlias = alias
        }
    }

    @ViewBuilder func aliasInput() -> some View {
        AliasInput(stack: stack.push(),
                    text: $alias,
               lastAlias: lastAlias,
            changeAction: { lookupState = .unknown })
        .focused($focus, equals: .alias)
        .onSubmit { focus = nil }
    }

    var body: some View {
        if let aliasTypes,
           let configuration = controller.mailboxConfiguration {
            let type = aliasTypes[selectedType]
            let contacts = controller.contacts
            List {
                Group {
                    VStack(alignment: .leading, spacing: 6) {
                        picker(aliasTypes)
                        aliasInput()
                    }
                    switch lookupState {
                        case .unknown:
                            if !alias.isEmpty {
                                Text("Check whether this alias is already registered:")
                                lookupButton(type)
                                    .padding(.horizontal)
                            }
                        case .unregistered:
                            Text("This alias is not registered yet. Do you want to register it now?")
                            registerButton(type, configuration: configuration)
                                .padding()
                        case .confirmed(let targetUri, let validFor):
                            if targetUri.contains(configuration.hAddress) {
                                Text("This alias, valid for \(validFor.toDays()) days, is already registered to the mailbox on this phone.")
                                if contacts.firstIndex(where: {$0.alias == alias}) == nil {
                                    Text("But it is not in your contacts list. Add it now?")
                                    addContactButton(type, address: configuration.hAddress)
                                }

                                Text("If you no longer want to use it, you can unregister it now.")
                                registerButton(type, configuration: configuration)
                                    .padding(.horizontal)
                            } else {
                                Text("This alias is registered to another mailbox:")
                                Text(targetUri.description)
                            }
                        case .registered(let targetUri, let validFor):
                            // TODO: let the user register again to get another mail/SMS
                            switch type.name {
                                case "email":
                                    Text("Check your email inbox for a confirmation email.")
                                case "phone":
                                    Text("Check your messages for a confirmation SMS.")
                                default:
                                    Text("Check \(type.localized) for a confirmation code.")
                            }
                            codeInput()
                            if challenge.isEmpty {
                                Text("You can also confirm the registration directly on the website, then come back here and check whether it was successful:")
                                lookupButton(type)
                                    .padding(.horizontal)
                            } else {
                                confirmButton(type, targetUri)
                                    .padding(.horizontal)
                            }
                        case .error:
                            Text("Cannot check this alias...")
//                            Text(error.0)
//                                .foregroundColor(.red)
//                            Text(error.1)
//                                .foregroundColor(.red)
                    }
                }
                .talerFont(.title3)
                .listRowSeparator(.hidden)

                // TODO: once we have services that charge money for TalDir, we should show the remaining time
//                if let validFor {
//                    Text("Valid for \(validFor.toDays()) days")
//                }
            }
            .listStyle(myListStyle.style).anyView
            .navigationTitle(navTitle)
            .onAppear() {
                DebugViewC.shared.setViewID(VIEW_ALIAS, stack: stack.push())
            }
        } else {
            LoadingView(stack: stack.push(), scopeInfo: nil, message: "Loading supported alias types")
                .task { await viewDidLoad() }
        }
    } // body
}
