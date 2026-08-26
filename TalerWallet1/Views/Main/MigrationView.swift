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
    @State private var progress: Double = 0

    func buttonAction() {
        if !isMigrating {
            Task {
//                try? await model.migrateDatabase()
            }
            withAnimation {
                self.isMigrating = true
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

    func cancelAction() {
        self.isMigrating = false
        // TODO: cancel migration
        finishAction()
    }

    func finishAction() {
        withAnimation {
            controller.backendState = .ready
        }
    }
    var body: some View {
        List {
            Section(header: Text("Update database")) {
                if isFinished {
                    Text("Finished")
                        .talerFont(.title)
                        .task {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                finishAction()
                            }
                        }
                } else if isMigrating {
                    if fakeMigration {
                        Text("Faking migration")
                            .talerFont(.title)
                            .task {
                                for x in 0...100 {
                                    await Task.sleep(20_000_000)
                                    self.progress = Double(x) / 100
                                }
                                withAnimation {
                                    isFinished = true
                                }
                            }
                    } else {
                        Text("Updating the database:")
                            .talerFont(.title)
                    }
                    ProgressView(value: progress)
                    Button("Cancel", action: cancelAction)
                        .buttonStyle(TalerButtonStyle(type: .bordered))
                        .padding()
                } else {
                    Text("The money database needs to be updated.")
                        .talerFont(.title)
                    Text("This might take a while...")
                        .talerFont(.body)

                    Button("Update now", action: buttonAction)
                        .buttonStyle(TalerButtonStyle(type: .bordered, disabled: isMigrating))
                        .disabled(isMigrating)
                        .padding()
                    if developerMode {
                        Button("Fake update", action: fakeAction)
                            .buttonStyle(TalerButtonStyle(type: .bordered, disabled: isMigrating))
                            .disabled(isMigrating)
                            .padding()
                    }
                    Button("Update later", action: finishAction)
                        .buttonStyle(TalerButtonStyle(type: .bordered))
                        .padding()
                }
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(myListStyle.style).anyView
        .talerFont(.title2)
        .background(FullBackground())
    }
}


struct MigrationView_Previews: PreviewProvider {
    static var previews: some View {
        MigrationView()
    }
}
