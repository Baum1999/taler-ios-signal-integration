/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import SwiftUI
import taler_swift
import SymLog
import AVFoundation

/// This view shows the list of balances / currencies, each in its own section

struct BalancesListView: View {
    private let symLog = SymLogV(0)
    let navTitle: String
    let hamburgerAction: () -> Void

    @State var balances: [Balance] = []
    @EnvironmentObject private var model: WalletModel

    @State private var centsToTransfer: UInt64 = 0
    @State private var summary: String = ""
    @State private var showQRScanner: Bool = false
    @State private var showCameraAlert: Bool = false

    var ClosingAnnouncement = AttributedString(localized: "Closing Camera")
    private var openSettingsButton: some View {
        Button("Open Settings") {
            showCameraAlert = false
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
//            AccessibilityNotification.Announcement(ClosingAnnouncement).post()
            showCameraAlert = false
        }
    }

    var defaultPriorityAnnouncement = AttributedString(localized: "Opening Camera")
    var lowPriorityAnnouncement: AttributedString {
        var lowPriorityString = AttributedString ("Camera Loading")
        //        lowPriorityString.accessibilitySpeechAnnouncementPriority = .low
        return lowPriorityString
    }
    var highPriorityAnnouncement: AttributedString {
        var highPriorityString = AttributedString("Camera Active")
        //        highPriorityString.accessibilitySpeechAnnouncementPriority = .high
        return highPriorityString
    }
    private func checkCameraAvailable() -> Void {
        /// Open Camera Code
//        AccessibilityNotification.Announcement(defaultPriorityAnnouncement).post()
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) -> Void in
            if granted {
                showQRScanner = true
            } else {
                // Camera Loaded Code
//                AccessibilityNotification.Announcement(highPriorityAnnouncement).post()
                showCameraAlert = true
            }
        })
    }

    private func reloadAction() async {
        balances = await model.balancesM()
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Content(symLog: symLog, balances: $balances,
                centsToTransfer: $centsToTransfer, summary: $summary,
                reloadAction: reloadAction)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: HamburgerButton(action: hamburgerAction),
                                trailing: QRButton(action: checkCameraAvailable))
            .overlay {
                if balances.isEmpty {
                    WalletEmptyView()
                }
            }
            .alert("Scanning QR-codes requires access to the camera",
                   isPresented: $showCameraAlert,
                       actions: {   openSettingsButton
                                    dismissAlertButton },
                       message: {   Text("Please allow camera access in settings.") })
            .onAppear() {
                DebugViewC.shared.setViewID(VIEW_BALANCES)
            }
            .sheet(isPresented: $showQRScanner) {
                let sheet = AnyView(QRSheet())
                Sheet(sheetView: sheet)
            } // sheet
            .task {
                symLog.log(".task fetchBalancesM")
                await reloadAction()
            } // task
    }
}
// MARK: -
extension BalancesListView {
    struct Content: View {
        let symLog: SymLogV?
        @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
        @Binding var balances: [Balance]
        @Binding var centsToTransfer: UInt64
        @Binding var summary: String
        var reloadAction: () async -> Void

        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            Group { // necessary for .backslide transition (bug in SwiftUI)
                List(balances, id: \.self) { balance in
                    BalancesSectionView(balance: balance,
                                centsToTransfer: $centsToTransfer,
                                        summary: $summary)
                }
                .refreshable {
                    symLog?.log("refreshing")
                    await reloadAction()      // this closure is already async, no need for a Task
                }
                .listStyle(myListStyle.style).anyView
            }
            // automatically fetch balances after receiving transaction-state-transition ...
            .onNotification(.TransactionStateTransition) { notification in
                // doesn't need to be received on main thread because we just reload in the background anyway
                symLog?.log(".onNotification(.TransactionStateTransition) ==> reloading balances")
                Task { await reloadAction() }
            }
        } // body
    } // Content
}
