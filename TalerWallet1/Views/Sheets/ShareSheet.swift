/*
 * This file is part of GNU Taler, ©2022-23 Taler Systems S.A.
 * See LICENSE.md
 */
import Foundation
import UIKit
import SymLog

// You can control the appearance of the link by providing view content.
// For example, you can use a Label to display a link with a custom icon:
//    ShareLink(item: URL(string: "https://developer.apple.com/xcode/swiftui/")!) {
//        Label("Share", image: "MyCustomShareIcon")
//    }
// If you only wish to customize the link’s title, you can use one of the convenience
// initializers that takes a string and creates a Label for you:
//    ShareLink("Share URL", item: URL(string: "https://developer.apple.com/xcode/swiftui/")!)
// The link can share any content that is Transferable.
// Many framework types, like URL, already conform to this protocol.


public class ShareSheet: ObservableObject {
    private let symLog = SymLogC()

    @MainActor static func shareSheet(url: String) {
        let url = URL(string: url)
        let activityView = UIActivityViewController(activityItems: [url!], applicationActivities: nil)

        let allScenes = UIApplication.shared.connectedScenes
        let scene = allScenes.first { $0.activationState == .foregroundActive }

        if let windowScene = scene as? UIWindowScene {
            windowScene.keyWindow?.rootViewController?.present(activityView, animated: true, completion: nil)
        }
    }

    init() {
        symLog.log("init")

    }
}
