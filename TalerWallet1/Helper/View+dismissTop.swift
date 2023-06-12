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

// John Sundell
extension View {
    func onNotification(
        _ notificationName: Notification.Name,
        perform action: @escaping () -> Void
    ) -> some View {
        onReceive(NotificationCenter.default
                    .publisher(for: notificationName)
        ) { _ in
            action()
        }
    }
    func onNotification(
        _ notificationName: Notification.Name,
        perform action: @escaping (_ notification: Notification) -> Void
    ) -> some View {
        onReceive(NotificationCenter.default
            .publisher(for: notificationName)
        ) { notification in
            action(notification)
        }
    }

    func onNotificationM(       // M for main thread
        _ notificationName: Notification.Name,
        perform action: @escaping () -> Void
    ) -> some View {
        onReceive(NotificationCenter.default
                    .publisher(for: notificationName)
                    .receive(on: RunLoop.main)
        ) { _ in
            action()
        }
    }

    func onNotificationM(       // M for main thread
        _ notificationName: Notification.Name,
        perform action: @escaping (_ notification: Notification) -> Void
    ) -> some View {
        onReceive(NotificationCenter.default
            .publisher(for: notificationName)
            .receive(on: RunLoop.main)
        ) { notification in
            action(notification)
        }
    }

    func onAppEnteredBackground(
        perform action: @escaping () -> Void
    ) -> some View {
        onNotification(
            UIApplication.didEnterBackgroundNotification,
            perform: action
        )
    }
}

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
