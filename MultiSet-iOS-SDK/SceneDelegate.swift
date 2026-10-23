/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can’t re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import UIKit
import SwiftUI
import MultiSetSDK

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: LandingView())
        self.window = window
        window.makeKeyAndVisible()
    }

    /// Re-issues map uploads a force-quit or a lost connection interrupted.
    func sceneDidBecomeActive(_ scene: UIScene) {
        Task { await MultiSet.shared.mapping.resumeUploads() }
    }
}
