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

struct AboutView: View {
    private let symLog = SymLogV(0)
    let stack: CallStack
    let localizedAppName: String
    let navTitle: String

    @EnvironmentObject private var controller: Controller
#if DEBUG
    @AppStorage("developerMode") var developerMode: Bool = true
#else
    @AppStorage("developerMode") var developerMode: Bool = false
#endif
    @AppStorage("myListStyle") var myListStyle: MyListStyle = .automatic
    @AppStorage("minimalistic") var minimalistic: Bool = false
    @AppStorage("tapped") var tapped: Int = 0
    @AppStorage("dragged") var dragged: Int = 0

    @State private var rotationEnabled = false
    @State private var showGitHash = false
    @State private var listID = UUID()
    @State private var onboarding = false

    var body: some View {
#if PRINT_CHANGES
        let _ = Self._printChanges()
        let _ = symLog.vlog()       // just to get the # to compare it with .onAppear & onDisappear
#endif
        let walletCore = WalletCore.shared
        let size = 100.0
        let rotatingTaler = RotatingTaler(size: size,
                                      progress: false,
                                          once: true,
                               rotationEnabled: $rotationEnabled)
            .accessibilityHidden(true)   // has its own accessibilityLabel
            .frame(maxWidth: .infinity, alignment: .center)
            .onTapGesture(count: 1) { rotationEnabled.toggle() }
        Group {
            List {
                if #available(iOS 17.7, *) {
                    let talerURI = TALER_NET
                    BorderWithHCE(talerURI: talerURI, nfcHint: false, size: size, scanHints: nil) {
                        rotatingTaler
                    }
                } else {
                    rotatingTaler
                }
                SettingsItem(name: String(localized: "Visit the taler.net website"),
                              id1: "webTaler",
                        imageName: LINK,
                      description: String(localized: "More info about GNU Taler in general")) { }
                    .accessibilityAddTraits(.isLink)
                    .accessibilityRemoveTraits(.isStaticText)
                    .onTapGesture() {
                        UIApplication.shared.open(URL(string:TALER_NET)!, options: [:])
                    }

                SettingsItem(name: String(localized: "Open \(localizedAppName) settings"),
                              id1: "webSettings",
                        imageName: SETTINGS,
                      description: String(localized: "System settings -> Apps")) { }
                    .accessibilityAddTraits(.isLink)
                    .accessibilityRemoveTraits(.isStaticText)
                    .onTapGesture() {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:])
                    }

                SettingsItem(name: String(localized: "App Version"), id1: "app") {
                    Text(verbatim: "\(Bundle.main.releaseVersionNumberPretty)")
                }
                Group {
                    if showGitHash {
                        SettingsItem(name: "Wallet-Core Git", id1: "wallet-coreG") {
                            if let gitHash = walletCore.versionInfo?.implementationGitHash {
                                let index = gitHash.index(gitHash.startIndex, offsetBy: 7)
                                Text(gitHash[..<index])
                            } else {
                                Text(verbatim: "unknown")
                            }
                        }
                    } else {
                        SettingsItem(name: String(localized: "Wallet-Core Version"), id1: "wallet-coreV") {
                            Text(verbatim: "\(walletCore.versionInfo?.implementationSemver ?? "unknown")")
                        }
                    }
                }.onTapGesture(count: 1) { showGitHash.toggle() }
                
                SettingsToggle(name: String(localized: "Onboarding"),
                               value: $onboarding.onChange({ shouldOnboard in
                                    if shouldOnboard {
                                        tapped = 0
                                        dragged = 0
                                    } else {
                                        tapped = TAPPED
                                        dragged = DRAGGED
                                    }
                                }),
                                id1: "onboarding",
                        description: String(localized: "Explain the Actions button"))
#if DEBUG
                Text(verbatim: "Tapped: \(tapped), dragged: \(dragged)")
#endif

//                SettingsItem(name: "Supported Exchange Versions", id1: "exchange") {
//                    Text(verbatim: "\(walletCore.versionInfo?.exchange ?? "unknown")")
//                }
//                SettingsItem(name: "Supported Merchant Versions", id1: "merchant") {
//                    Text(verbatim: "\(walletCore.versionInfo?.merchant ?? "unknown")")
//                }
//                SettingsItem(name: "Used Bank", id1: "bank") {
//                    Text(verbatim: "\(walletCore.versionInfo?.bank ?? "unknown")")
//                }
            }
            .id(listID)
            .listStyle(myListStyle.style).anyView
        }
        .navigationTitle(navTitle)
        .task {
            onboarding = (tapped < TAPPED || dragged < DRAGGED)
//            try? await Task.sleep(nanoseconds: 1_000_000_000 * UInt64(5))
//            rotationEnabled.toggle()
        }
        .onAppear() {
            DebugViewC.shared.setViewID(VIEW_ABOUT, stack: stack.push())
        }
    }
}
extension Bundle {
    var bundleName: String? {
        return infoDictionary?["CFBundleDisplayName"] as? String
    }
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String {
        let build = infoDictionary?["CFBundleVersion"]
        let zero = "0"
        if let build {
            return build as? String ?? zero
        }
        return zero
    }
    var releaseVersionNumberPretty: String {
        let release = releaseVersionNumber ?? "1.0.0"
        return release // "v\(release) (\(buildVersionNumber))"
    }
}
// MARK: -
#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView(stack: CallStack("Preview"), localizedAppName: "GNU Taler", navTitle: "About")
    }
}
#endif
