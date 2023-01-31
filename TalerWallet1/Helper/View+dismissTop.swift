/*
 * This file is part of GNU Taler
 * (C) 2022 Taler Systems S.A.
 *
 * GNU Taler is free software; you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 3, or (at your option) any later version.
 *
 * GNU Taler is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * GNU Taler; see the file COPYING.  If not, see <http://www.gnu.org/licenses/>
 */
import SwiftUI

/// This is just a workaround for a SwiftUI bug
/// A presented sheet (SwiftUI view) doesn't always close when calling "dismiss()" provided by @Environment(\.dismiss),
/// so we are walking the view stack to find the top presentedViewController (UIKit) and dismiss it.
extension View {
    public func dismissTop(animated: Bool = true) {
        let windows = UIApplication.shared.connectedScenes.compactMap {
            ($0 as? UIWindowScene)?.keyWindow       // TODO: iPad might have more than 1 window
        }
        if var topController = windows.first?.rootViewController {
            var gotPresented = false
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
                gotPresented = true
            }
            if gotPresented {
                topController.dismiss(animated: animated)
            } else {
                print("Yikes❗️ Trying to dismiss the rootViewController!")
            }
        } else {
            print("Yikes❗️ There is no window/rootViewController!")
        }
    }
}
