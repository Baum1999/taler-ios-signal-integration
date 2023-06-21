//  MIT License
//  Copyright © John Sundell
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
