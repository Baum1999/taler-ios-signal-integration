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
    let navTitle = String(localized: "GNU Taler")       // + Wallet
    @AppStorage("listStyle") var myListStyle = MyListStyle.automatic

    @ObservedObject var model: BalancesModel
    var hamburgerAction: () -> Void

    @State private var centsToTransfer: UInt64 = 0        // TODO: maybe Decimal?
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

    var body: some View {
#if DEBUG
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let reloadAction = model.fetchBalancesM
        Content(symLog: symLog, model: model, centsToTransfer: $centsToTransfer,
                reloadAction: reloadAction, myListStyle: $myListStyle)
            .navigationTitle(navTitle)
            .navigationBarItems(leading: HamburgerButton(action: hamburgerAction),
                                trailing: QRButton(action: checkCameraAvailable))
            .alert("Scanning QR-codes requires access to the camera",
                   isPresented: $showCameraAlert,
                       actions: {   openSettingsButton
                                    dismissAlertButton },
                       message: {   Text("Please allow camera access in settings.") })
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
        @ObservedObject var model: BalancesModel
        @Binding var centsToTransfer: UInt64
        var reloadAction: () async -> ()
        @Binding var myListStyle: MyListStyle

        var body: some View {
#if DEBUG
            let _ = Self._printChanges()
            let _ = symLog?.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
            Group {
                List (model.balances, id: \.self) { balance in
                    let model = TransactionsModel.model(currency: balance.available.currencyStr)
                    BalancesSectionView(balance: balance, centsToTransfer: $centsToTransfer, model: model)
                }
                .refreshable {
                    symLog?.log("refreshing")
                    await reloadAction()      // this closure is already async, no need for a Task
                }
                .listStyle(myListStyle.style)
                .anyView
            }
            .navigationBarTitleDisplayMode(.automatic)
            .onAppear() {
                DebugViewC.shared.setViewID(VIEW_BALANCES)
            }
            .overlay {
                if model.balances.isEmpty {
                    WalletEmptyView()
                        .background(WalletColors().backgroundColor.edgesIgnoringSafeArea(.all))
                }
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
