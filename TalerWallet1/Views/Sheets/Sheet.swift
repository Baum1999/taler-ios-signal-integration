/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import SwiftUI
import SymLog
import os.log

enum SheetType: Equatable, Identifiable, Hashable {
    case action
    case scanner
    case url(URL)

    var id: String {
        switch self {
            case .action:
                return "action"
            case .scanner:
                return "scanner"
            case .url(let url):
                return url.absoluteString
        }
    }

    static func == (lhs: SheetType, rhs: SheetType) -> Bool {
        switch (lhs, rhs) {
            case (.action, .action):
                return true
            case (.scanner, .scanner):
                return true
            case (.url(let lhsUrl), .url(let rhsUrl)):
                return lhsUrl == rhsUrl
            default:
                return false
        }
    }
}

struct Sheet: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    var sheetView: AnyView

    @Environment(\.dismiss) var dismiss     // call dismiss() to get rid of the sheet
    @EnvironmentObject private var debugViewC: DebugViewC
    @EnvironmentObject private var model: WalletModel
    @EnvironmentObject private var controller: Controller
    @AppStorage("talerFontIndex") var talerFontIndex: Int = 0
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif

    let logger = Logger(subsystem: "net.taler.gnu", category: "Sheet")

    var cancelButton: some View {
        Button("Cancel") {
            logger.log("Cancel")
            dismissTop(stack.push())
        }
    }

    var body: some View {
        let idString = debugViewC.sheetID > 0 ? String(debugViewC.sheetID)
                                              : EMPTYSTRING      // show nothing if 0
        VStack(spacing: 0) {
            if controller.networkUnavailable {
                ErrorBanner(.networkUnavailable)    // red bar on top
            } else if controller.slowConnection {
                ErrorBanner(.warning5sec)           // yellow bar on top
            }
            ZStack {
                NavigationView {
                    sheetView
                }
                .navigationBarTitleDisplayMode(.automatic)
                .background(FullBackground())
                .navigationViewStyle(.stack)
                .talerNavBar(talerFontIndex: talerFontIndex)
                .overlay(alignment: .top) {
                    // Show the viewID on top of the sheet's NavigationView
                    Text(idString)
                        .foregroundColor(.purple)
                        .font(.system(size: 11))        // no talerFont
                        .monospacedDigit()
                        .ignoresSafeArea(edges: .top)
                        .id("sheetID")
                        .accessibilityLabel(Text("Sheet.ID.", comment: "a11y"))
                        .accessibilityValue(idString)
                }
                if let error2 = model.error2 {
                    ErrorView(stack.push(), data: error2, devMode: developerMode) {
                        model.setError(nil)
                        logger.log("ErrorSheet dismissTop")
                        dismissTop(stack.push())
                    }
                    .background(FullBackground())
                }
            }
        }
        .onDisappear {
            symLog.log("❗️❗️Sheet onDisappear")
        }
    }
}
