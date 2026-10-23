/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import UIKit

/// Holds the scan screen in landscape, the orientation every shipped capture was recorded in.
///
/// The host's app delegate must return `OrientationLock.shared.mask` from
/// `application(_:supportedInterfaceOrientationsFor:)` for the lock to take effect.
@MainActor
final class OrientationLock {
    static let shared = OrientationLock()

    /// A delegate answering `supportedInterfaceOrientationsFor` overrides the Info.plist
    /// outright, so the default has to be what the plist grants this idiom.
    static var hostDefault: UIInterfaceOrientationMask {
        let idiomKey = UIDevice.current.userInterfaceIdiom == .pad
            ? "UISupportedInterfaceOrientations~ipad" : "UISupportedInterfaceOrientations~iphone"
        let names = (Bundle.main.object(forInfoDictionaryKey: idiomKey)
            ?? Bundle.main.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations")) as? [String] ?? []
        var mask: UIInterfaceOrientationMask = []
        for name in names {
            switch name {
            case "UIInterfaceOrientationPortrait": mask.insert(.portrait)
            case "UIInterfaceOrientationPortraitUpsideDown": mask.insert(.portraitUpsideDown)
            case "UIInterfaceOrientationLandscapeLeft": mask.insert(.landscapeLeft)
            case "UIInterfaceOrientationLandscapeRight": mask.insert(.landscapeRight)
            default: break
            }
        }
        return mask.isEmpty ? .all : mask
    }

    private(set) var mask: UIInterfaceOrientationMask = OrientationLock.hostDefault

    func restoreDefault() {
        let hostDefault = Self.hostDefault
        let returnsToPortrait = UIDevice.current.userInterfaceIdiom != .pad && hostDefault.contains(.portrait)
        set(hostDefault, preferred: returnsToPortrait ? .portrait : nil)
    }

    func set(_ newMask: UIInterfaceOrientationMask, preferred: UIInterfaceOrientationMask? = nil) {
        mask = newMask
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        if let preferred {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: preferred))
        }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}
