/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

extension View {
    /// A system alert over the camera takes its colour from what is behind it, where the
    /// accent measures about 1.3:1. Attach every `.alert` above this and every `.sheet` below.
    func msARDialogTint() -> some View {
        tint(MSColor.AR.text)
    }
}
