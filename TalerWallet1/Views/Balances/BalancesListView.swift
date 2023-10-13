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
    private let symLog = SymLogV()
    let stack: CallStack
    let navTitle: String
    let hamburgerAction: () -> Void

    @EnvironmentObject private var model: WalletModel
    @State private var balances: [Balance] = []
    @State private var centsToTransfer: UInt64 = 0
    @State private var summary: String = ""
    @State private var showQRScanner: Bool = false
    @State private var showCameraAlert: Bool = false

    private var openSettingsButton: some View {
        Button("Open Settings") {
            showCameraAlert = false
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
    var ClosingAnnouncement = AttributedString(localized: "Closing Camera")
    private var dismissAlertButton: some View {
        Button("Cancel", role: .cancel) {
            if #available(iOS 17.0, *) {
//                AccessibilityNotification.Announcement(ClosingAnnouncement).post()
            }
            showCameraAlert = false
        }
    }

    var defaultPriorityAnnouncement = AttributedString(localized: "Opening Camera")
    var lowPriorityAnnouncement: AttributedString {
        var lowPriorityString = AttributedString ("Camera Loading")
        if #available(iOS 17.0, *) {
//            lowPriorityString.accessibilitySpeechAnnouncementPriority = .low
        }
        return lowPriorityString
    }
    var highPriorityAnnouncement: AttributedString {
        var highPriorityString = AttributedString("Camera Active")
        if #available(iOS 17.0, *) {
//            highPriorityString.accessibilitySpeechAnnouncementPriority = .high
        }
        return highPriorityString
    }
    private func checkCameraAvailable() -> Void {
        /// Open Camera Code
        if #available(iOS 17.0, *) {
//            AccessibilityNotification.Announcement(defaultPriorityAnnouncement).post()
        }
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) -> Void in
            if granted {
                showQRScanner = true
            } else {
                // Camera Loaded Code
                if #available(iOS 17.0, *) {
//                    AccessibilityNotification.Announcement(highPriorityAnnouncement).post()
                }
                showCameraAlert = true
            }
        })
    }

    /// runs on MainActor if called in some Task {}
    @discardableResult
    private func reloadAction(_ stack: CallStack) async -> Int {
        let reloaded = await model.balancesM(stack.push())
        let count = reloaded.count
        balances = reloaded         // redraw
        return count
    }

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        Content(symLog: symLog, stack: stack.push(), balances: $balances,
                centsToTransfer: $centsToTransfer, summary: $summary,
                reloadAction: reloadAction)
            .navigationTitle(navTitle)
            .navigationBarItems(leading: HamburgerButton(action: hamburgerAction),
                                trailing: QRButton(action: checkCameraAvailable))
            .overlay {
                if balances.isEmpty {
                    WalletEmptyView(stack: stack.push())
                        .refreshable {  // already async
                            symLog.log("empty refreshing")
                            let count = await reloadAction(stack.push("empty refreshing"))
                            if count > 0 {
//                                postNotificationM(.BalanceReloaded)
                                NotificationCenter.default.post(name: .BalanceReloaded, object: nil)
                            }
                        }
                }
            }
            .alert("Scanning QR-codes requires access to the camera",
                   isPresented: $showCameraAlert,
                       actions: {   openSettingsButton
                                    dismissAlertButton },
                       message: {   Text("Please allow camera access in settings.") })
            .onAppear() {
                DebugViewC.shared.setViewID(VIEW_BALANCES, stack: stack.push("onAppear"))
            }
            .sheet(isPresented: $showQRScanner) {
                let sheet = AnyView(QRSheet(stack: stack.push()))
                Sheet(sheetView: sheet)
            } // sheet
            .task {
                symLog.log(".task getBalances")
                await reloadAction(stack.push(".task"))
            } // task
    }
}
// MARK: -
extension BalancesListView {
    struct Content: View {
        let symLog: SymLogV?
        let stack: CallStack
        @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
        @Binding var balances: [Balance]
        @Binding var centsToTransfer: UInt64
        @Binding var summary: String
//        @discardableResult
        var reloadAction: (_ stack: CallStack) async -> Int

        @State private var isActive = true
        @State private var shouldReload = false

        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            Group { // necessary for .backslide transition (bug in SwiftUI)
                let count = balances.count
                List(balances, id: \.self) { balance in
                    BalancesSectionView(stack: stack.push(),
                                        balance: balance,
                                   sectionCount: count,
                                centsToTransfer: $centsToTransfer,
                                        summary: $summary)
                }
                .refreshable {  // already async
                    symLog?.log("refreshing")
                    let count = await reloadAction(stack.push("refreshing"))
                    if count > 0 {
//                        postNotificationM(.BalanceReloaded)
                        NotificationCenter.default.post(name: .BalanceReloaded, object: nil)
                    }
                }
                .listStyle(myListStyle.style).anyView
            }
            .onAppear() {
                isActive = true
                if shouldReload {
                    shouldReload = false
                    symLog?.log(".onAppear ==>  shouldReload was true, reloading now")
                    Task { await reloadAction(stack.push("shouldReload")) } // runs on MainActor
                }
            }
            .onDisappear() {
                isActive = false
            }
            .onNotification(.BalanceChange) { notification in
                // reload balances on receiving BalanceChange notification ...
                // doesn't need to be received on main thread because we just reload in a background task anyway
                if isActive {
                    symLog?.log(".onNotification(.BalanceChange) ==> reload")
                    Task { await reloadAction(stack.push(".BalanceChange")) }
                } else {
                    symLog?.log(".onNotification(.BalanceChange) ==> reload postponed, shouldReload = true")
                    shouldReload = true
                }
            }
        } // body
    } // Content
}
