/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

/// Instructions, then the scan, as one cover's content. A second cover nested inside the
/// first left controls stranded after a landscape scan and flashed the instructions on exit.
struct MappingFlowView: View {
    let kind: MappingCaptureKind
    let onClose: () -> Void

    @State private var showsScan = MappingInstructionsView.isSuppressed

    var body: some View {
        if !showsScan {
            MappingInstructionsView(onStart: { showsScan = true }, onCancel: onClose)
        } else if kind == .posedRGB {
            PosedRGBScanView()
        } else {
            ScanView()
        }
    }
}

extension MappingCaptureKind {
    var title: String {
        switch self {
        case .lidar: "LiDAR"
        case .posedRGB: "Non-LiDAR"
        @unknown default: "Scan"
        }
    }

    var summary: String {
        switch self {
        case .lidar: "Camera images, depth and a mesh from the LiDAR scanner."
        case .posedRGB: "Camera images and their poses, no LiDAR needed. Best in textured, well-lit spaces."
        @unknown default: ""
        }
    }
}
