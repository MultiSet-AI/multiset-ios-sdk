/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// GPS status indicator component
struct GpsIndicator: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 10, height: 10)

            // Label
            Text("GPS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }
}

#if DEBUG
struct GpsIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            GpsIndicator(isActive: true)
            GpsIndicator(isActive: false)
        }
        .padding()
        .background(Color.gray)
    }
}
#endif
