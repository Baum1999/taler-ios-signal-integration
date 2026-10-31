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

struct TalDirSettingsView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle: String

    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
//    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("acceptAutomatically") var acceptAutomatically: Bool = false
    @AppStorage("deleteAutomatically") var deleteAutomatically: Bool = false
//    @AppStorage("minimalistic") var minimalistic: Bool = false

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let list = List {
            Section {
                let contacts = "contacts"
                let contactsDest = ContactsView(stack: stack.push(contacts), talerURI: nil, subject: nil)
                NavigationLink {
                    contactsDest
                } label: {
                    SettingsItem(name: contactsDest.navTitle, id1: contacts,
                            imageName: ICONNAME_PERSON3,    // 􀝊
                          description: String(localized: "Manage contact information")) {}
                }
            } // contacts
            if let configuration = controller.mailboxConfiguration {
                Section {
                    let mailboxTitle = String(localized: "TitleMailbox", defaultValue: "Mailbox")
                    let mailboxDest = MailboxView(stack: stack.push(mailboxTitle),
                                               navTitle: mailboxTitle)
                    NavigationLink {
                        mailboxDest
                    } label: {
                        SettingsItem(name: mailboxTitle, id1: "mailbox",
                                imageName: ICONNAME_MAILBOX,    // 􀍷
                              description: String(localized: "P2P Messaging")) {}
                    }.listRowSeparator(.hidden)
                    SettingsToggle(name: String(localized: "Automatically accept"),
                                  value: $acceptAutomatically,
                                    id1: "acceptAutomatically",
                            description: String(localized: "...incoming payments, skip confirmation")
                    ).listRowSeparator(.hidden)
                    SettingsToggle(name: String(localized: "Automatically delete"),
                                  value: $deleteAutomatically,
                                    id1: "deleteAutomatically",
                            description: String(localized: "...messages after the transaction finishes")
                    )

                    let aliasTitle = String(localized: "TitleAlias", defaultValue: "Alias Registration")
                    let aliasDest = AliasView(stack: stack.push(aliasTitle),
                                           navTitle: aliasTitle)
                    NavigationLink {
                        aliasDest
                    } label: {
                        SettingsItem(name: aliasTitle, id1: "alias",
                                imageName: ICONNAME_ALIAS,    // 􀲏
                              description: String(localized: "Taldir Registration")) {}
                    }

                }
            } else {
                Text("You need a TalDir mailbox to be able to receive money that other people send to your TalDir Alias.")
                    .listRowSeparator(.hidden)
                Text("Once you have a mailbox, create Aliases and publish them on your website, GitHub page, or any other place.")
                    .listRowSeparator(.hidden)
                Button("Create Mailbox") {
                    Task {
                        await controller.createMailbox()
                    }
                }
                .buttonStyle(TalerButtonStyle(type: .bordered))
                .padding()
                Text("Your mailbox will be hosted at gnunet.org. Currently there is no fee. Other providers may charge a small monthly fee.")
                    .listRowSeparator(.hidden)
            }
        }
            .listStyle(myListStyle.style).anyView
            .navigationTitle(navTitle)
            .onAppear() {
                DebugViewC.shared.setViewID(VIEW_SETTINGS4, stack: stack.push())
            }
        if #available(iOS 26.0, *) {
            list
        } else {
            list
                .padding(.bottom)
        }
    } // body
}
