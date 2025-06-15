/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import taler_swift
import SymLog

let PREFIX = "Taler-"

/// This view shows the list of backups
struct BackupView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var amountLastUsed = Amount.zero(currency: EMPTYSTRING)      // needed for Deposit, ignore
    @State private var created: Bool = false
    @State private var files: [String] = []
    @State private var filename: String = ""
    @State private var selectedBackup: String? = nil
    @State private var showRestoreAlert: Bool = false


    private func createBackup() {
        created = true
        Task {
            let dateString = Date().iso
            let stem = String(PREFIX + dateString)
            if let backupFile = try? await model.exportDbToFile(stem: stem) {
                filename = backupFile
            }
        }
    }

    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            showRestoreAlert = false
            selectedBackup = nil
        }
    }
    private var resetButton: some View {
        Button("Restore", role: .destructive) {                                   // TODO: WalletColors().errorColor
//            didReset = true

            showRestoreAlert = false
            Task { // runs on MainActor
                symLog.log("❗️Restore \(selectedBackup)❗️")
//                try? await model.resetWalletCore()
                selectedBackup = nil
            }
        }
    }



    @MainActor
    private func viewDidLoad() async {
        let fm = FileManager.default
        if let docDirUrl = URL.docDirUrl {
            if let contentsOfDocDir = try? fm.contentsOfDirectory(at: docDirUrl,
                                          includingPropertiesForKeys: nil,
                                                             options: []) {
                withAnimation { files = contentsOfDocDir.map { $0.lastPathComponent } }
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let a11yLabelStr = String(localized: "Add bank account", comment: "a11y for the + button")
        let addTitleStr = String(localized: "Add bank account", comment: "title of the addExchange alert")
        let buttonTitle = String(localized: "Create Backup", comment: "button")


        let backupHint = Text("Tap 'Create Backup' to make a copy of your digital money. Connect your iPhone to a computer, then use the Files dialog and copy that backup to your computer's harddisk.")

        let restoreHint = Text("To restore your digital money, connect your iPhone to your computer, then use the Files dialog and copy a previously saved backup from your computer into the Taler Wallet.")

        let backups = files.filter { $0.hasPrefix(PREFIX) }
        List {
            Section {
                backupHint
                    .listRowSeparator(.hidden)
                Button(buttonTitle) { createBackup() }
                    .buttonStyle(TalerButtonStyle(type: .bordered))
                    .padding()
                    .listRowSeparator(.hidden)
                    .disabled(created)
                restoreHint
            }
#if DEBUG
            Text(filename)
#endif
            if !backups.isEmpty {
                Section {
                    ForEach(backups, id: \.self) { file in
                        Text(file)
                            .onTapGesture {
                                selectedBackup = file
                            }
                    }
                }
            }
        }
        .listStyle(myListStyle.style).anyView
        .task { await viewDidLoad() }
        .navigationTitle(navTitle)
        .onChange(of: selectedBackup) { selected in
            if selected != nil {
                showRestoreAlert = true
            }
        }
        .alert("Overwrite Wallet",
               isPresented: $showRestoreAlert,
               actions: { dismissAlertButton
                          resetButton },
               message: { Text("Are you sure you want to overwrite your wallet with this backup?\nThis cannot be reverted, all money which is now still in your wallet will be lost.") })
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_BANK_ACCOUNTS, stack: stack.push())
        }
    } // body
}
