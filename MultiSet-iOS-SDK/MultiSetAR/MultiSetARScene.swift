/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import ARKit

/// The adapter's shared state: one renderer, one GPS provider, and the frame source for the
/// attached session.
final class MultiSetARScene {

    static let shared = MultiSetARScene()

    let renderer = RealityKitSceneRenderer()
    let geoHintProvider = CoreLocationGeoHintProvider()

    /// Weak so that only the SDK keeps the session alive, as before the split. Identity still
    /// holds while the SDK has the source attached, which is the only time it matters.
    private weak var frameSource: ARSessionFrameSource?

    /// Weak for the same reason: `MultiSetARView.Coordinator` owns it for the ARView's
    /// lifetime, so a reset arriving after the view is gone finds nothing and does nothing.
    weak var sessionController: ARSessionController?

    private init() {}

    /// Returns the same wrapper for the same session. The SDK resets its pose consistency
    /// reference whenever the frame source's identity changes, so a fresh wrapper per call
    /// would throw the reference away on every attach.
    func frameSource(for session: ARSession?) -> ARSessionFrameSource? {
        renderer.session = session

        guard let session = session else {
            frameSource = nil
            return nil
        }

        if let existing = frameSource, existing.session === session {
            return existing
        }

        let source = ARSessionFrameSource(session: session)
        source.sessionController = sessionController
        frameSource = source
        return source
    }

    func isAttached(_ session: ARSession) -> Bool {
        return frameSource?.session === session
    }
}
