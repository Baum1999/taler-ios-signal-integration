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
    let stack: CallStack
    let navTitle: String
    @Binding var balances: [Balance]
    @Binding var shouldReloadBalances: Int
#if TABBAR  // Taler Wallet
#else       // GNU Taler
    let hamburgerAction: () -> Void
#endif

    @EnvironmentObject private var model: WalletModel

    @State private var lastReloadedBalances = 0
    @State private var amountToTransfer = Amount.zero(currency: EMPTYSTRING)    // Update currency when used
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
                AccessibilityNotification.Announcement(ClosingAnnouncement).post()
            }
            showCameraAlert = false
        }
    }
    private func dismissingSheet() {
        if #available(iOS 17.0, *) {
            AccessibilityNotification.Announcement(ClosingAnnouncement).post()
        }
    }

    var defaultPriorityAnnouncement = AttributedString(localized: "Opening Camera")
    var lowPriorityAnnouncement: AttributedString {
        var lowPriorityString = AttributedString ("Camera Loading")
        if #available(iOS 17.0, *) {
            lowPriorityString.accessibilitySpeechAnnouncementPriority = .low
        }
        return lowPriorityString
    }
    var highPriorityAnnouncement: AttributedString {
        var highPriorityString = AttributedString("Camera Active")
        if #available(iOS 17.0, *) {
            highPriorityString.accessibilitySpeechAnnouncementPriority = .high
        }
        return highPriorityString
    }
    private func checkCameraAvailable() -> Void {
        // Open Camera when QR-Button was tapped
        if #available(iOS 17.0, *) {
            AccessibilityNotification.Announcement(defaultPriorityAnnouncement).post()
        }
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) -> Void in
            if granted {
                showQRScanner = true            // present sheet
                if #available(iOS 17.0, *) {
                    AccessibilityNotification.Announcement(highPriorityAnnouncement).post()
                }
            } else {
                showCameraAlert = true
            }
        })
    }

    /// runs on MainActor if called in some Task {}
    @discardableResult
    private func reloadBalances(_ stack: CallStack, _ invalidateCache: Bool) async -> Int {
        if invalidateCache {
            model.cachedBalances = nil
        }
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
#if TABBAR  // Taler Wallet
        let hamburger: HamburgerButton? = nil
#else       // GNU Taler
        let hamburger: HamburgerButton = HamburgerButton(action: hamburgerAction)
#endif
        Content(symLog: symLog, stack: stack.push(), balances: $balances,
                amountToTransfer: $amountToTransfer, summary: $summary,
                reloadBalances: reloadBalances)
            .navigationTitle(navTitle)
            .navigationBarItems(leading: hamburger,
                                trailing: QRButton(action: checkCameraAvailable))
            .alert("Scanning QR-codes requires access to the camera",
                   isPresented: $showCameraAlert,
                       actions: {   openSettingsButton
                                    dismissAlertButton },
                       message: {   Text("Please allow camera access in settings.") })
            .sheet(isPresented: $showQRScanner, onDismiss: dismissingSheet) {
                let sheet = AnyView(QRSheet(stack: stack.push()))
                Sheet(sheetView: sheet)
            } // sheet
            .task(id: shouldReloadBalances) {
                symLog.log(".task shouldReloadBalances \(shouldReloadBalances)")
                let invalidateCache = (lastReloadedBalances != shouldReloadBalances)
                lastReloadedBalances = shouldReloadBalances
                await reloadBalances(stack.push(".task"), invalidateCache)
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
        @Binding var amountToTransfer: Amount
        @Binding var summary: String
        var reloadBalances: (_ stack: CallStack, _ invalidateCache: Bool) async -> Int

        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            Group { // necessary for .backslide transition (bug in SwiftUI)
                let count = balances.count
                if balances.isEmpty {
                    WalletEmptyView(stack: stack.push("isEmpty"))
                } else {
                    List(balances, id: \.self) { balance in
                        BalancesSectionView(stack: stack.push("\(balance.scopeInfo.currency)"),
                                          balance: balance,                     // this is the currency to be used
                                     sectionCount: count,
                                 amountToTransfer: $amountToTransfer,           // does still have the wrong currency
                                          summary: $summary)
                    }
                    .onAppear() {
                        DebugViewC.shared.setViewID(VIEW_BALANCES, stack: stack.push("onAppear"))
                    }
                    .listStyle(myListStyle.style).anyView
                }
            }
            .refreshable {  // already async
                symLog?.log("refreshing balances")
                let count = await reloadBalances(stack.push("refreshing balances"), true)
                if count > 0 {
                    NotificationCenter.default.post(name: .BalanceReloaded, object: nil)
                }
            }
        } // body
    } // Content
}
