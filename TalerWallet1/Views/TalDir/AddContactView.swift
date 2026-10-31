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
// Called when scanning an add_contact QR code, or tapping an add_contact talerURI
// Or the user saves their own alias after registering it
struct AddContactView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let url: URL?
    let contact: ContactEntry?
    let navTitle: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var created: Bool = false
    @State private var working: Bool = false
    @State private var lookupState: LookupState = .unknown
    @State private var selectedType: Int = 0
    @State private var lastType: Int? = nil
    @State private var unknownType: String = EMPTYSTRING
    @State private var alias: String = EMPTYSTRING
    @State private var lastAlias: String = EMPTYSTRING
    @State private var mailbox: String = EMPTYSTRING
    @State private var mailAddress: String = EMPTYSTRING
    @State private var sourceBaseUrl: String = EMPTYSTRING
    @State private var petname: String = EMPTYSTRING
    @State private var isSelf: Bool = false
    @State private var targetUri: String? = nil
    @State private var aliasTypes: [TaldirAliasType]? = nil

    private enum FocusField { case alias, mbox, address, source, pet }
    @FocusState private var focus: FocusField?

    init(_ stack: CallStack, url: URL? = nil, contact: ContactEntry? = nil, navTitle: String? = nil) {
        self.stack = stack
        self.url = url
        self.contact = contact
        self.navTitle = navTitle ??
            String(localized: "TitleAddContact", defaultValue: "Add Contact", comment: "View Title, Button")
    }

    private func selectType(_ type: String) {
        var typeIsSupported = false
        if let aliasTypes {
            for index in aliasTypes.indices {
                let aliasType = aliasTypes[index]
                if aliasType.name == type {
                    selectedType = index
                    typeIsSupported = true
                    break
                }
            }
        }
        if !typeIsSupported {
            unknownType = type
        }
    }

    @MainActor
    private func viewDidLoad() async {
        if aliasTypes == nil {
            if let types = try? await model.getSupportedAliasTypes() {
                aliasTypes = types
            }
        }
        if let url {
            // we only arrive here when the command is .addContact, so no need to test this again
            let parts = url.path.split(separator: "/")
            if parts.count == 4 {
                selectType(parts[0].lowercased())
                alias = parts[1].lowercased()
                mailbox = HTTPS + parts[2].lowercased()
                mailAddress = parts[3].lowercased()
                if let queryParameters = url.queryParameters {
                    if let baseUrl = queryParameters["sourceBaseUrl"] {
                        sourceBaseUrl = baseUrl
                    }
                }
                // TODO: perform lookup
                lookupState = .confirmed(mailAddress, Duration.microseconds(0))
            }
        } else if let contact {
            selectType(contact.aliasType.lowercased())
            alias = contact.alias.lowercased()
            mailbox = contact.mailboxBaseUrl.lowercased()
            mailAddress = contact.mailboxAddress.lowercased()
            sourceBaseUrl = contact.source.lowercased()
            petname = contact.petname
            isSelf = contact.isSelf ?? false
            // TODO: perform lookup
            lookupState = .confirmed(mailAddress, Duration.microseconds(0))
        }
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

    @ViewBuilder func lookupButton(_ aliasType: TaldirAliasType) -> some View {
        LookupButton(stack: stack.push(),
                     alias: alias,
                 aliasType: aliasType,
               lookupState: $lookupState,
                     focus: { focus = nil }
        ) {
            lastType = selectedType
            lastAlias = alias

            var targetUri: String? = nil
            var validFor: Duration? = nil
            switch lookupState {
                case .registered(let newUri, let newDuration):
                    targetUri = newUri
                    validFor = newDuration
                case .confirmed(let newUri, let newDuration):
                    targetUri = newUri
                    validFor = newDuration
                default: break
            }
            if let targetUri,
               let url = URL(string: targetUri) {
                if let host = url.host,
                   let scheme = url.scheme {
                    mailbox = scheme + "://" + host
                }
                var path = url.relativePath
                if path.hasPrefix("/") {
                    path.removeFirst()
                }
                mailAddress = path
                sourceBaseUrl = TALDIR
            }
        }
    }

    @ViewBuilder func aliasInput() -> some View {
        AliasInput(stack: stack.push(),
                    text: $alias,
               lastAlias: lastAlias,
            changeAction: { lookupState = .unknown })
        .focused($focus, equals: .alias)
        .onSubmit { focus = .mbox }
    }

    @ViewBuilder func mailboxInput() -> some View {
        StandardInput(stack: stack.push(),
                      label: String(localized: "Mailbox:", comment: "TextEdit purpose, a11y"),
                placeHolder: MAILBOX,
                       text: $mailbox)
        .focused($focus, equals: .mbox)
        .onSubmit { focus = .address }
    }

    @ViewBuilder func sourceInput() -> some View {
        StandardInput(stack: stack.push(),
                      label: String(localized: "Source:", comment: "TextEdit purpose, a11y"),
                placeHolder: EMPTYSTRING,
                       text: $sourceBaseUrl)
        .focused($focus, equals: .source)
        .onSubmit { focus = .pet }
    }

    @ViewBuilder func petInput() -> some View {
        StandardInput(stack: stack.push(),
                      label: String(localized: "Nickname:", comment: "TextEdit purpose, a11y"),
                placeHolder: EMPTYSTRING,
                       text: $petname)
        .focused($focus, equals: .pet)
        .onSubmit { focus = nil }
    }

    @ViewBuilder func addContactButton(_ aliasType: TaldirAliasType) -> some View {
//        let title = String(localized: "Confirm", comment: "button")
        FeedbackButton(navTitle, disabled: working, haptic: false) {
            working = true
            focus = nil    // dismiss keyboard
            let newContact = ContactEntry(alias: alias,
                                      aliasType: aliasType.name,
                                 mailboxBaseUrl: mailbox,
                                 mailboxAddress: mailAddress.uppercased(),  // TODO: remove this after fix
                                         source: sourceBaseUrl,
                                        petname: petname,
                                         isSelf: isSelf)
            Task {
                do {
                    try await model.addContact(newContact)
                } catch {    // it didn't succeed
                             // TODO: show error
                    print("addContact failed")
                    lookupState = .error
                }
                self.working = false
                dismissTop(stack.push())
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        if let aliasTypes {
            let type = aliasTypes[selectedType]
            List {
                Group {
                    VStack(alignment: .leading, spacing: 6) {
                        picker(aliasTypes)
                        aliasInput()
                    }
                    switch lookupState {
                        case .unknown:
                            if !alias.isEmpty {
                                Text("Check whether this alias is registered at the Taler Directory:")
                                lookupButton(type)
                                    .padding(.horizontal)
                            } else {
#if DEBUG
                                HStack {
                                    Button("t11") {
                                        petname = "t11"
                                        alias = "t11@fesh.com"
                                    }.padding(.horizontal)
                                    Spacer()
                                    Button("t15") {
                                        petname = "t15"
                                        alias = "t15@fesh.com"
                                    }.padding(.horizontal)
                                }.buttonStyle(.bordered)
#endif
                            }
                        case .unregistered:
                            Text("This alias is not registered at the Taler Directory.")
//                            registerButton(type)
                                .padding()
                        case .confirmed(let targetUri, let validFor):
                            if let configuration = controller.mailboxConfiguration,
                               targetUri.contains(configuration.hAddress) {
                                Text("This alias, valid for \(validFor.toDays()) days, is already registered to the mailbox on this phone.")
                            } else {
                                Text("This alias is registered to:")
                            }
                        case .registered(let targetUri, let validFor):
                            Text("This alias is registered, but not valid yet.")
                        case .error:
                            Text("Cannot check this alias...")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        mailboxInput()
                        Text("leave blank to use default mailbox")
                            .talerFont(.subheadline)
                    }

                    MailAddressInput(stack: stack.push(),
                                      text: $mailAddress,
                                 isFocused: focus == .address)
                    { focus = .source }
                        .focused($focus, equals: .address)

                    sourceInput()

                    petInput()

                    SettingsToggle(name: String("Belongs to me"), value: $isSelf,
                                    id1: "isSelf",
                            description: String("May be on another wallet"))

                    addContactButton(type)
                }
                .talerFont(.title3)
                .listRowSeparator(.hidden)
            }
            .listStyle(myListStyle.style).anyView
            .navigationTitle(navTitle)
        } else {
            LoadingView(stack: stack.push(), scopeInfo: nil, message: "Loading supported alias types")
                .task { await viewDidLoad() }
        }
    }
}
