/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import RealityKit

/// Shows the camera of a mapping source, with the live reconstruction drawn over it
struct MultiSetMappingARView: UIViewRepresentable {
    let source: ARMappingSource

    func makeUIView(context: Context) -> ARView { source.arView }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
