/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can’t re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/


import UIKit
import MultiSetSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Load any saved user settings before AR views read the config, so a
        // previous run's saved values are applied on this launch.
        ConfigStore.shared.load()
        return true
    }

    /// A map upload that finished or failed while the app was not running relaunches it here.
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        MultiSet.shared.mapping.handleEventsForBackgroundURLSession(identifier: identifier, completionHandler: completionHandler)
    }

    /// Answering this overrides the Info.plist, which is how the scan screen holds landscape.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.shared.mask
    }

    // The window lives in SceneDelegate: apps built with the iOS 27 SDK fail to launch
    // without the UIScene life cycle.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
