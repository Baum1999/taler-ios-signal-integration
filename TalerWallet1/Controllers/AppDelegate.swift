/*
 * This file is part of GNU Taler, ©2022-26 Taler Systems S.A.
 * See LICENSE.md
 */
/**
 * AppDelegate
 *
 * @author Marc Stibane
 */
import SwiftUI
import SymLog

class AppDelegate: NSObject, UIApplicationDelegate {
    private let symLog = SymLogC()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
//        @AppStorage("pushNotifications") var pushNotifications: Bool = false

//        symLog.log("App has launched successfully!")
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.hexEncodedString()
        symLog.log("deviceToken: \(tokenString)")
        Controller.shared.deviceTokenAPNs = tokenString
        // TODO: tell walletCore
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        symLog.log("Failed to register for remote notifications with error: \(error)")
        // TODO: tell the user...
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        symLog.log(userInfo)
        // TODO: react on receiving a background notification
//        guard let groupId = userInfo[PushNotificationKeys.groupId] as? String else {
//            completionHandler(.noData)
//            return
//        }
//        notificationsCenterService.removeDeliveredNotifications(groupId: groupId)
        completionHandler(.newData)
    }
}
