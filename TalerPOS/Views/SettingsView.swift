/*
 * This file is part of GNU Taler
 * (C) 2026 Bohdan, Volodymyr Potuzhnyi
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING. If not, see <http://www.gnu.org/licenses/>
 */

import SwiftUI


private struct LanguageOption: Identifiable {
    let tag: String
    let label: String
    var id: String { tag }
}

private let supportedLanguages: [LanguageOption] = [
    LanguageOption(tag: "", label: S.settingsLanguageSystemDefault),
    LanguageOption(tag: "en", label: "English"),
    LanguageOption(tag: "de", label: "Deutsch"),
    LanguageOption(tag: "es", label: "Español"),
    LanguageOption(tag: "fi", label: "Suomi"),
    LanguageOption(tag: "fr", label: "Français"),
    LanguageOption(tag: "it", label: "Italiano"),
    LanguageOption(tag: "ru", label: "Русский"),
    LanguageOption(tag: "sv", label: "Svenska"),
    LanguageOption(tag: "tr", label: "Türkçe"),
    LanguageOption(tag: "uk", label: "Українська"),
    LanguageOption(tag: "he", label: "עברית"),
]

struct SettingsView: View {
    @EnvironmentObject var configManager: ConfigManager
    @ObservedObject private var languageManager = LanguageManager.shared
    let onNavigate: (PosDestination) -> Void
    var openDrawer: (() -> Void)?

    private var username: String? {
        guard !configManager.merchantUrl.isEmpty,
              let url = URL(string: configManager.merchantUrl) else { return nil }
        return url.pathComponents.last(where: { !$0.isEmpty && $0 != "/" })
    }

    var body: some View {
        VStack(spacing: 0) {
            PosTopBar(title: S.menuSettings, onMenuTap: { openDrawer?() })
            List {
            Section {
                Picker(S.settingsInitialOrderLabel, selection: Binding(
                    get: { configManager.initialOrderScreen },
                    set: { configManager.setInitialOrderScreen($0) }
                )) {
                    Text(S.menuAmountEntry).tag(InitialOrderScreen.amountEntry)
                    Text(S.menuOrder).tag(InitialOrderScreen.inventory)
                }

                Picker(S.settingsLanguageLabel, selection: Binding(
                    get: { languageManager.selectedLanguage },
                    set: { languageManager.setLanguage($0) }
                )) {
                    ForEach(supportedLanguages) { lang in
                        if lang.tag.isEmpty, let resolved = languageManager.resolvedLanguageLabel {
                            Text("\(lang.label) (\(resolved))").tag(lang.tag)
                        } else {
                            Text(lang.label).tag(lang.tag)
                        }
                    }
                }
            } header: {
                Text(S.settingsAppTitle)
                    .foregroundColor(.posOnSurface)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(S.settingsInstanceDescription)
                        .font(.subheadline)
                        .foregroundColor(.posOnSurface)

                    Button {
                        onNavigate(.config)
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.2")
                            Text(S.settingsInstanceButton)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.posPrimaryContainer)
                        .foregroundColor(.posOnPrimaryContainer)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        configManager.logout()
                    } label: {
                        Text(S.settingsLogoutButton)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.posErrorContainer)
                            .foregroundColor(.posOnErrorContainer)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(S.settingsInstanceTitle)
                    .foregroundColor(.posOnSurface)
            }

            Section {
                aboutRow(label: S.appName, value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                if let username {
                    aboutRow(label: S.configUsername, value: username)
                }
                if !configManager.merchantUrl.isEmpty {
                    let suffix = configManager.backendVersion.map { " (\($0))" } ?? ""
                    aboutRow(label: S.configMerchantUrl, value: "\(configManager.merchantUrl)\(suffix)")
                }
            } header: {
                Text(S.settingsAboutTitle)
                    .foregroundColor(.posOnSurface)
            }

        }
        .scrollContentBackground(.hidden)
        .background(Color.posSurface)
        }
        .background(Color.posSurface)
        .navigationBarHidden(true)
        .toast(message: Binding(
            get: { languageManager.languageChangedToast },
            set: { languageManager.languageChangedToast = $0 }
        ), duration: 4)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .fontWeight(.bold)
            Text(value)
        }
        .font(.subheadline)
        .foregroundColor(.posOnSurfaceVariant)
    }
}
