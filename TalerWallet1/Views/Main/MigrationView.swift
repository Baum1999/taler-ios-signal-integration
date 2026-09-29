/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
import taler_swift

struct MigrationView: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @EnvironmentObject private var controller: Controller
    @EnvironmentObject private var model: WalletModel
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("preferredColorScheme") var preferredColorScheme: Int = 0
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic

    @State private var isMigrating: Bool = false
    @State private var fakeMigration: Bool = false
    @State private var isFinished: Bool = false
    @State private var isCancelled: Bool = false
    @State private var progress: Double = 0
    @State private var error2: Error? = nil
    @State private var showTechHint: Bool = false

    func chevronAction() {
        withAnimation {
            showTechHint.toggle()
        }
    }
    func buttonAction() {
        if !isMigrating {
            withAnimation {
                self.isMigrating = true
            }
            Task {
                let result = try? await model.migrateDatabase()
                if let migrated = result?.migrated {
                    withAnimation {
                        isFinished = migrated
                        self.progress = 1
                    }
                }
            }
        }
    }

    func fakeAction() {
        if !isMigrating {
            fakeMigration = true
            withAnimation {
                self.isMigrating = true
            }
        }
    }

    // Too much hassle for wallet-core to check this everywhere
//    func cancelAction() {
//        self.isMigrating = false
//        self.isCancelled = true
//        if let operation = controller.progressOperation,
//           let token = controller.progressToken {
//            Task {
//                try? await model.cancelProgressToken(operation, token: token)
//                controller.progressOperation = nil
//                controller.progressToken = nil
//            }
//        }
//    }

    func finishAction() {
        withAnimation {
            controller.backendState = .ready
        }
    }

    var body: some View {
        let list = List {
            Section(header: Text("Update database")) {
                if isMigrating || isFinished || isCancelled {
                    if fakeMigration {
                        Text("Simulating update:")
                            .talerFont(.title)
                            .task {
                                for x in 0...90 {
                                    await Task.sleep(20_000_000)
                                    self.progress = Double(x) / 100
                                }
                                withAnimation {
                                    isFinished = true
                                    self.progress = 1
                                }
                                controller.hapticFeedback(.medium)
                            }
                    } else {
                        Text("Updating the database:")
                            .talerFont(.title)
                    }
                    ProgressView(value: progress)
//                    Button("Cancel", action: cancelAction)
//                        .buttonStyle(TalerButtonStyle(type: .bordered))
//                        .padding()
                    if isFinished || isCancelled {
                        Text(isCancelled ? "Cancelled" : "Finished")
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
                } else {
                    let device = controller.isIpad ? Text("this iPad", comment: "device")
                                                   : Text("this iPhone", comment: "device")
                    Text("The \(controller.localizedAppName) database on \(device) can be updated and will then be faster.", comment: "appName, device")
                        .talerFont(.title)
                    Text("This might take from a few seconds to a minute or two, depending on how many transactions you made.")
                        .talerFont(.body)

                    Button("Update now", action: buttonAction)
                        .buttonStyle(TalerButtonStyle(type: .bordered, disabled: isMigrating))
                        .disabled(isMigrating)
                        .padding()
#if TALER_NIGHTLY || GNU_TALER
                    if developerMode {
                        Button("Simulate update", action: fakeAction)
                            .buttonStyle(TalerButtonStyle(type: .bordered, disabled: isMigrating))
                            .disabled(isMigrating)
                            .padding()
                    }
#endif
                    Button("Update later", action: finishAction)
                        .buttonStyle(TalerButtonStyle(type: .bordered))
                        .padding()

                    Button(action: chevronAction) {
                        let chevron = Image(systemName: CHEVRON_UP)     // 􀆇
                        HStack(alignment: .firstTextBaseline) {
                                Text("Technical information")
                                    .talerFont(.body)
                            Spacer()
                            chevron.rotationEffect(.degrees((showTechHint ?  -180 : 0)))
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityHint(Text(showTechHint ? "Hide Technical information"
                                                             : "Show Technical information"))
                        .contentShape(.rect)    // can tap in background also
                    }   .buttonStyle(.plain)
                    if showTechHint {
                        Text("The database, which holds your money and your transactions, is updated from \"indexed\" to \"sqlite3\" format.\nThe app cannot be used during that time.")
                            .talerFont(.body)
                    }
                }
            }
            .listRowSeparator(.hidden)
        }.id("list")
        .listStyle(myListStyle.style).anyView
        .talerFont(.title2)
        .onNotification(.DatabaseMaintenance) { notification in
            if let payload = notification.userInfo?[NOTIFICATIONPAYLOAD] as? WalletCore.Payload {
                if let error = payload.error {
                    self.error2 = WalletBackendError.walletCoreError(error)
                } else if let percent = payload.completionPercent {
                    withAnimation {
                        progress = Double(percent) / 100
                    }
                }
            }
        }
        let stack = ZStack {
            if preferredColorScheme == 3, #available(iOS 17.0, *) {
                list.scrollContentBackground(.hidden)
            } else {
                list
            }
            if let error2 {
                ErrorView(nil, error: error2, devMode: developerMode) {
                    self.error2 = nil
                }.interactiveDismissDisabled()
            }
        }.id("stack")
        NavigationView {
            ZStack {
                WalletHeader(showSettings: false, content: stack)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FullBackground())
        }.navigationViewStyle(.stack)
    }
}
