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

let BACKUP = "Taler-"
let PREFIX = "file://"

/// This view shows the list of backups
struct BackupView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var created: Bool = false
    @State private var restored: Bool = false
    @State private var backups: [String] = []
    @State private var filename: String = EMPTYSTRING
    @State private var selectedBackup: String? = nil
    @State private var showRestoreAlert: Bool = false

    private func restoreBackup(_ path: String) {
        restored = true
        Task {
            try? await model.importDbFromFile(path: path)
        }
    }

    private func createBackup() {
        created = true
        Task {
            let dateString = Date().iso
            let stem = String(BACKUP + dateString)
            if let backupFile = try? await model.exportDbToFile(stem: stem) {
                filename = backupFile
                await viewDidLoad()
            }
        }
    }

    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            showRestoreAlert = false
            withAnimation { selectedBackup = nil }
        }
    }
    private var resetButton: some View {
        Button("Restore", role: .destructive) {                                   // TODO: WalletColors().errorColor
//            didReset = true

            if let selectedBackup, let docDirUrl = URL.docDirUrl {
                showRestoreAlert = false
//                symLog.log("❗️Restore \(selectedBackup)❗️")
//                if #available(iOS 16.0, *) {
//                    backupPath = docDirUrl.appending(component: selectedBackup)
//                }
                let backupPath = docDirUrl.appendingPathComponent(selectedBackup).absoluteString
                let path = backupPath.deletingPrefix(PREFIX)
                symLog.log("❗️Restore \(path)❗️")
                restoreBackup(path)
                withAnimation { self.selectedBackup = nil }
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
                let filenames = contentsOfDocDir.map { $0.lastPathComponent }
                backups = filenames.filter { $0.hasPrefix(BACKUP) }.sorted(by: >)
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let buttonTitle = String(localized: "Create Backup", comment: "button")

        let backupHint = Text("Tap 'Create Backup' to make a copy of your digital money. Connect your iPhone to a computer, then use the Files dialog and copy that backup to the computer.")

        let restoreHint = Text("To restore your digital money, tap on the backup you want to restore from the list below.")

        let restoreHint2 = Text("To restore on a different iPhone, first install the Taler Wallet app there. Then connect it to your computer, and use the Files dialog to copy a previously saved backup into the Taler Wallet. Finally open the Backup/Restore dialog there, and select the backup you just copied.")
        let hasBackups = !backups.isEmpty
        List {
            Section {
                backupHint
                    .listRowSeparator(.hidden)
                FeedbackButton(buttonTitle, disabled: created) { createBackup() }
                    .padding(.horizontal)
                    .listRowSeparator(.hidden)
                restoreHint
                restoreHint2
            }
            .talerFont(.body)

            Section {
                if hasBackups {
                    ForEach(backups, id: \.self) { file in
                        let isSelected = file == selectedBackup
                        HStack {
                            Text(file)
                                .padding(.vertical, 2)
                            Spacer()
                        }
                        .background {
                            Color.primary.opacity(isSelected ? 0.12 : 0.001)
                        }
                        .onTapGesture {
                            withAnimation { selectedBackup = file }
                            showRestoreAlert = true
                        }
                    }
                } else {
                    Text("No backups yet...")
                        .talerFont(.body)
                }
            } header: {
                Text("Available for restore:")
                    .talerFont(.title3)
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
            DebugViewC.shared.setViewID(VIEW_BACKUP, stack: stack.push())
        }
    } // body
}
