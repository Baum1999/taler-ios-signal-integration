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
struct ContactRowView: View {
    let stack: CallStack
    let contact: ContactEntry
    let talerURI: String?
    let subject: String?

    @EnvironmentObject private var model: WalletModel

    @State private var showAlert: Bool = false

    private var cancelButton: some View {
        Button("Cancel", role: .cancel) {
            showAlert = false
        }
    }

    private var sendNowButton: some View {
        Button(contact.petname.isEmpty ? "Send now" : "Send to \(contact.petname)") {
            showAlert = false
            if let talerURI {
                Task {
                    try? await model.sendTalerUriMailboxMessage(talerURI,
//                                                   subjectHint: subject ?? EMPTYSTRING,
                                                            to: contact)
                    dismissTop(stack.push())
                }
            }
        }
    }

    var body: some View {
        let label = VStack(alignment: .leading) {
            if !contact.petname.isEmpty {
                Text(contact.petname)
                    .talerFont(.title3)
            }
            Text(contact.alias)
                .talerFont(.body)
        }

        if let talerURI {       // send this to the selected contact
            label
                .contentShape(.rect)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    Color.primary.opacity(showAlert ? 0.12 : INVISIBLE)
                }
                .onTapGesture { showAlert.toggle() }
                .alert("Send to \(contact.petname)",
                       isPresented: $showAlert,
                       actions: {   sendNowButton
                                    cancelButton },
                       message: {   if let subject {
                                        Text(subject)
                                    } })

        } else {                // edit the selected contact
            NavigationLink {
                let title = String(localized: "TitleEditContact",
                                defaultValue: "Edit Contact", comment: "View Title, Button")
                AddContactView(stack.push(), contact: contact, navTitle: title)
            } label: { label }
        }
    }
}
// MARK: -
/// This view shows the list of contacts
///  called either from TalDir settings (without talerURI), or from CopyShare->TalDirButton (with talerURI)
struct ContactsView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let talerURI: String?
    let subject: String?

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var contacts: [ContactEntry]? = nil
    @State private var showAddDialog: Bool = false

    var navTitle: String {
        String(localized: "TitleContacts", defaultValue: "Contacts")
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let a11yLabelStr = String(localized: "Add Contact", comment: "a11y for the + button")
        let plusButton = PlusButton(accessibilityLabelStr: a11yLabelStr) {
            showAddDialog = true
        }
        let addContactDest = AddContactView(stack.push())
        let actions = Group {
            NavLink($showAddDialog) { addContactDest }
        }
        let contacts = controller.contacts
        let ownEntries = contacts.filter({$0.isSelf == true })
        let otherEntries = contacts.filter({$0.isSelf != true })
        List {
            if !ownEntries.isEmpty {
                Section(header: Text("Own contacts")) {
                    ForEachWithIndex(array: ownEntries) { index, contact in
                        ContactRowView(stack: stack.push(),
                                     contact: contact,
                                    talerURI: talerURI,
                                     subject: subject)
                    }
                }
            }
            Section {
                if otherEntries.isEmpty {
                    Text("No contacts yet...")
                } else {
                    ForEachWithIndex(array: otherEntries) { index, contact in
                        ContactRowView(stack: stack.push(),
                                     contact: contact,
                                    talerURI: talerURI,
                                     subject: subject)
                    }
                }
            }
        }
        .background(actions)
        .listStyle(myListStyle.style).anyView
//        .task { await viewDidLoad() }
        .refreshable {
            controller.hapticNotification(.success)
            symLog.log("refreshing")
            await controller.loadContacts(stack.push())
        }
        .navigationTitle(navTitle)
        .navigationBarItems(trailing: plusButton)
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_CONTACTS, stack: stack.push())
        }
    } // body
}
