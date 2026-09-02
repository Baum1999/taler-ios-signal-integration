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
    @State private var backups: [String] = []
    @State private var filename: String = EMPTYSTRING
    @State private var selectedBackup: String? = nil
    @State private var showRestoreAlert: Bool = false
    @State private var progress: Double = 0
    @State private var isRestoring: Bool = false
    @State private var isFinished: Bool = false
    @State private var finishedMS: Int = 0
    @State private var isCancelled: Bool = false

    private func restoreBackup(_ path: String) {
        Task {
            do {
                let sendTime = Date.now
                try await model.importDbFromFile(path: path)
                let timeUsed = Date.now - sendTime
                self.finishedMS = timeUsed.milliseconds
                withAnimation {
                    self.isFinished = true
                    self.progress = 1
                }
                controller.hapticFeedback(.medium)
            } catch {}
        }
    }

    private func createBackup(asJSON: Bool) {
        created = true
        Task {
            let dateString = Date().iso
            let stem = String(BACKUP + dateString)
            if let backupFile = try? await model.exportDbToFile(stem: stem, asJSON: asJSON) {
                filename = backupFile
                await viewDidLoad()
                controller.hapticFeedback(.medium)
            }
        }
    }

    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            showRestoreAlert = false
            withAnimation { selectedBackup = nil }
        }
    }
    private var restoreButton: some View {
        Button("Restore", role: .destructive) {                                   // TODO: WalletColors().errorColor
//            didReset = true

            if !isRestoring,
               let selectedBackup,
               let docDirUrl = URL.docDirUrl {
                showRestoreAlert = false
                withAnimation {
                    self.isRestoring = true
                }
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

    func finishAction() {
//        withAnimation {
//            _ = dismissTop(stack.push())
//        }
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
        let buttonTitle1 = String(localized: "Create JSON backup", comment: "button")
        let buttonTitle2 = String(localized: "Create sqlite backup", comment: "button")

        let backupHint = Text("Tap 'Create Backup' to make a copy of your digital money. Connect your iPhone to a computer, then use the Files dialog and copy that backup to the computer.")

        let restoreHint = Text("To restore your digital money, tap on the backup you want to restore from the list below.")

        let restoreHint2 = Text("To restore on a different iPhone, first install the Taler Wallet app there. Then connect it to your computer, and use the Files dialog to copy a previously saved backup into the Taler Wallet. Finally open the Backup/Restore dialog there, and select the backup you just copied.")
        let hasBackups = !backups.isEmpty
        let busyRestore = isRestoring || isFinished || isCancelled
        List {
            if !busyRestore {
                Section {
                    backupHint
                        .listRowSeparator(.hidden)
                    FeedbackButton(buttonTitle1, disabled: created) { createBackup(asJSON: true) }
                        .padding(.horizontal)
                        .listRowSeparator(.hidden)
                    FeedbackButton(buttonTitle2, disabled: created) { createBackup(asJSON: false) }
                        .padding(.horizontal)
                        .listRowSeparator(.hidden)
                    restoreHint
                    restoreHint2
                }
                .talerFont(.body)
            }
            Section {
                if busyRestore {
                    Text("Restoring the backup:")
                        .talerFont(.title)
                    ProgressView(value: progress)
                    if isFinished || isCancelled {
                        Text(isCancelled ? "Cancelled" : "Finished after \(finishedMS) ms.")
                            .talerFont(.title)
                            .task {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    finishAction()
                                }
                            }
                    } else {
                        Text("Please don't close the app now, or we need to start over next time.")
                            .talerFont(.body)
                    }
                } else if hasBackups {
                    ForEach(backups, id: \.self) { file in
                        let isSelected = file == selectedBackup
                        HStack {
                            Text(file)
                                .padding(.vertical, 2)
                            Spacer()
                        }
                        .background {
                            Color.primary.opacity(isSelected ? 0.12 : INVISIBLE)
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
                          restoreButton },
               message: { Text("Are you sure you want to overwrite your wallet with this backup?\nThis cannot be reverted, all money which is now still in your wallet will be lost.") })
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_BACKUP, stack: stack.push())
        }
        .onNotification(.DatabaseMaintenance) { notification in
            if let payload = notification.userInfo?[NOTIFICATIONPAYLOAD] as? WalletCore.Payload {
                if let error = payload.error {
                    model.setError(WalletBackendError.walletCoreError(error))
                } else if let percent = payload.completionPercent {
                    withAnimation {
                        progress = Double(percent) / 100
                    }
                }
            }
        }
    } // body
}
