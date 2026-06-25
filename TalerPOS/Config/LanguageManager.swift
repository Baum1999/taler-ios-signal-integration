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
    }

    func setLanguage(_ tag: String) {
        selectedLanguage = tag
        if tag.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        } else {
            UserDefaults.standard.set(tag, forKey: Self.storageKey)
        }
        bundle = Self.bundle(for: tag)
    }

    var locale: Locale {
        selectedLanguage.isEmpty ? .current : Locale(identifier: selectedLanguage)
    }

    private static func bundle(for languageTag: String) -> Bundle {
        guard !languageTag.isEmpty else { return .main }

        if let path = Bundle.main.path(forResource: languageTag, ofType: "lproj"),
           let lprojBundle = Bundle(path: path) {
            return lprojBundle
        }

        let base = languageTag.components(separatedBy: "-").first ?? languageTag
        if base != languageTag,
           let path = Bundle.main.path(forResource: base, ofType: "lproj"),
           let lprojBundle = Bundle(path: path) {
            return lprojBundle
        }

        return .main
    }
}
