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
    @MainActor func dismissTop(_ stack: CallStack, animated: Bool = true) {
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
                Self.findNavigationController(viewController: topController)?.popToRootViewController(animated: animated)
            }
        } else {
            print("Yikes❗️ There is no window/rootViewController!")
        }
    }
    @MainActor static func findNavigationController(viewController: UIViewController?) -> UINavigationController? {
        guard let viewController = viewController else {
            return nil
        }

        if let navigationController = viewController as? UITabBarController {
            return findNavigationController(viewController: navigationController.selectedViewController)
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
