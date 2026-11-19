/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// The five scanning instructions' illustrations, in `Assets.xcassets/Mapping`
enum InstructionImage: String, CaseIterable {
    case distance = "instruction-01"
    case coverOnce = "instruction-02"
    case steadySpeed = "instruction-03"
    case avoidRapid = "instruction-04"
    case floorCeiling = "instruction-05"

    /// Nil when the asset is absent, so a caller falls back rather than drawing an empty frame
    var image: Image? {
        UIImage(named: rawValue).map { Image(uiImage: $0) }
    }
}
