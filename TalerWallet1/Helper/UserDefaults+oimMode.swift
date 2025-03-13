/*
 * This file is part of GNU Taler, ©2022-25 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * @author Marc Stibane
 */
import Foundation

// https://developer.apple.com/forums/thread/764675?answerId=805946022#805946022
extension UserDefaults {
    private static let oimModeEnabledKey = "oimModeEnabled"
    @objc dynamic var oimModeEnabled: Bool {
        get { bool(forKey: UserDefaults.oimModeEnabledKey) }
        set { set(newValue, forKey: UserDefaults.oimModeEnabledKey) }
    }

    private static let diagnosticModeEnabledKey = "diagnosticModeEnabled"
    @objc dynamic var diagnosticModeEnabled: Bool {
        get { bool(forKey: UserDefaults.diagnosticModeEnabledKey) }
        set { set(newValue, forKey: UserDefaults.diagnosticModeEnabledKey) }
    }
}
