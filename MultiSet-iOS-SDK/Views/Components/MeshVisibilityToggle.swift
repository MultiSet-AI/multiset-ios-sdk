/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// Shows or hides the meshes a fix brought in. Only reports taps; the caller owns the state.
///
/// Offer it only once a mesh is in the scene: a control that hides nothing reads as broken.
struct MeshVisibilityToggle: View {
    let isOn: Bool
    let action: (Bool) -> Void

    private var fill: Color {
        isOn ? Color(hex: "#7B2CBF").opacity(0.9) : Color.black.opacity(0.6)
    }

    private var label: some View {
        HStack(spacing: 6) {
            Image(systemName: isOn ? "cube.transparent" : "cube.transparent.fill")
                .font(.system(size: 14, weight: .semibold))
            Text("Mesh")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundColor(isOn ? Color.white : Color.white.opacity(0.6))
    }

    var body: some View {
        Button { action(!isOn) } label: {
            label
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .background(Capsule().fill(fill))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        }
        .accessibilityLabel("Mesh")
        .accessibilityValue(isOn ? "Shown" : "Hidden")
        .accessibilityHint("Shows or hides the mesh drawn in the scene")
    }
}

#if DEBUG
struct MeshVisibilityToggle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MeshVisibilityToggle(isOn: true) { _ in }
            MeshVisibilityToggle(isOn: false) { _ in }
        }
        .padding()
        .background(Color.gray)
    }
}
#endif
