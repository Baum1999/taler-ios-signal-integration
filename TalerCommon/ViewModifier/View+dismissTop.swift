//  MIT License
//  Copyright © Nicolai Harbo
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
//  and associated documentation files (the "Software"), to deal in the Software without restriction,
//  including without limitation the rights to use, copy, modify, merge, publish, distribute,
//  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
import SwiftUI

/// This is just a workaround for a SwiftUI bug
/// A presented sheet (SwiftUI view) doesn't always close when calling "dismiss()" provided by @Environment(\.dismiss),
/// so we are walking the view stack to find the top presentedViewController (UIKit) and dismiss it.
extension View {
    @MainActor    @discardableResult
    func dismissTop(_ stack: CallStack? = nil, animated: Bool = true) -> Bool {
        let windows = UIApplication.shared.connectedScenes.compactMap {
            // TODO: iPad might have more than 1 window
            // TODO: see UIScreen+screenSize for keyWindow
            ($0 as? UIWindowScene)?.keyWindow
        }
        if var topController = windows.first?.rootViewController {
            var gotPresented = false
            var currentController = topController
            while let presentedViewController = currentController.presentedViewController {
                currentController = presentedViewController
                gotPresented = true
            }
            if gotPresented {
                currentController.dismiss(animated: animated)
                return true
            } else if let navController = Self.findNavigationController(viewController: topController) {
                navController.popToRootViewController(animated: animated)
                return true
            } else {
                print("Yikes❗️ There is no navigationController!")
            }
        } else {
            print("Yikes❗️ There is no window/rootViewController!")
        }
        return false
    }
    @MainActor static func findNavigationController(viewController: UIViewController?) -> UINavigationController? {
        guard let viewController = viewController else {
            return nil
        }

        if let tabBarController = viewController as? UITabBarController {
            return findNavigationController(viewController: tabBarController.selectedViewController)
        }

        if let navigationController = viewController as? UINavigationController {
            return navigationController
        }

        for childViewController in viewController.children {
            return findNavigationController(viewController: childViewController)
        }

        return nil
    }
}
// MARK: -
extension View {
    @MainActor
    static func endEditing() {
        UIApplication.shared.windows.forEach { $0.endEditing(true) }
    }
}
