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

import Foundation
import Combine
import os

private let logger = Logger(subsystem: "net.taler.pos", category: "LanguageManager")

/// Manages in-app language override. Changes apply immediately
/// without requiring an app restart.
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private static let storageKey = "pos_selected_language"

    @Published private(set) var bundle: Bundle = .main
    @Published private(set) var selectedLanguage: String = ""

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        selectedLanguage = saved
        bundle = Self.bundle(for: saved)
        logger.info("Init: saved=\(saved) appPreferred=\(Locale.preferredLanguages) systemPreferred=\(Self.systemPreferredLanguages) resolved=\(self.bundle.bundlePath)")
    }

    @Published var languageChangedToast: String?

    func setLanguage(_ tag: String) {
        let previousTag = selectedLanguage
        selectedLanguage = tag
        if tag.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set(tag, forKey: Self.storageKey)
            UserDefaults.standard.set([tag], forKey: "AppleLanguages")
        }
        bundle = Self.bundle(for: tag)
        logger.info("setLanguage: tag=\(tag) AppleLanguages=\(UserDefaults.standard.object(forKey: "AppleLanguages") as? [String] ?? []) resolved=\(self.bundle.bundlePath)")
        if tag != previousTag {
            languageChangedToast = S.toastLanguageChanged
        }
    }

    var locale: Locale {
        selectedLanguage.isEmpty ? .current : Locale(identifier: selectedLanguage)
    }

    var resolvedLanguageLabel: String? {
        guard selectedLanguage.isEmpty else { return nil }
        let resolved = Self.resolveSystemLanguage()
        return Locale.current.localizedString(forLanguageCode: resolved)
    }

    private static var systemPreferredLanguages: [String] {
        let value = CFPreferencesCopyValue(
            "AppleLanguages" as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        return value as? [String] ?? Locale.preferredLanguages
    }

    private static func resolveSystemLanguage() -> String {
        let systemLangs = systemPreferredLanguages
        let available = Set(Bundle.main.localizations)
        for lang in systemLangs {
            if available.contains(lang) { return lang }
            let base = lang.components(separatedBy: "-").first ?? lang
            if available.contains(base) { return base }
        }
        return "en"
    }

    private static func bundle(for languageTag: String) -> Bundle {
        let tag = languageTag.isEmpty ? resolveSystemLanguage() : languageTag
        return lprojBundle(for: tag) ?? .main
    }

    private static func lprojBundle(for tag: String) -> Bundle? {
        if let path = Bundle.main.path(forResource: tag, ofType: "lproj"),
           let b = Bundle(path: path) {
            return b
        }
        let base = tag.components(separatedBy: "-").first ?? tag
        if base != tag,
           let path = Bundle.main.path(forResource: base, ofType: "lproj"),
           let b = Bundle(path: path) {
            return b
        }
        return nil
    }
}
