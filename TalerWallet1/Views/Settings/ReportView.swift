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

//let BACKUP = "Taler-"
//let PREFIX = "file://"

/// This view shows the list of backups
struct ReportView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let navTitle: String

    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var creating: Bool = false
    @State private var report: String = EMPTYSTRING
    @State private var expanded: Bool = false

    private func createReport() {
        creating = true
        Task {
            if let diagnostics = try? await model.getDiagnostics() {
                report = diagnostics
            }
        }
    }

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let buttonTitle = String(localized: "Create Report", comment: "button")

        let reportHint = Text("Tap 'Create Report' to build a report of your wallet's state, to help improve Taler...\nThis report will not enable the receiver to access your money.")

        List {
            Section {
                if report.isEmpty {
                    reportHint
                    Button(buttonTitle) { createReport() }
                        .buttonStyle(TalerButtonStyle(type: .bordered, disabled: creating))
                        .padding()
                } else {
                    Text(report)
                        .multilineTextAlignment(.leading)
                        .lineLimit(expanded ? nil : 3)
                        .onTapGesture {
                            expanded.toggle()
                        }
                    CopyShare(report, image: nil)
                }
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(myListStyle.style).anyView
        .navigationTitle(navTitle)
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_BANK_ACCOUNTS, stack: stack.push())
        }
    } // body
}
