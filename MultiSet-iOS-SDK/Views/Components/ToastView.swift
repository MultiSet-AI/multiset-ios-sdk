/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// Toast notification view component
struct ToastView: View {
    let message: String
    var isSuccess: Bool = true

    var body: some View {
        Text(message)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(radius: 4)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var backgroundColor: Color {
        isSuccess ? Color.black.opacity(0.7) : Color.red.opacity(0.8)
    }
}

/// Where a toast sits above the bottom of the screen.
enum ToastInset {

    /// The default, for screens whose bottom edge is empty.
    static let standalone: CGFloat = 100

    /// Clears an AR screen's bottom control row, which a flat inset does not: the row carries
    /// the watermark clearance, so with the watermark up it reaches well past 100 and the toast
    /// lands on top of the mesh toggle and the capture button.
    ///
    /// Mirrors the row in `ARLocalizationView` / `ARObjectTrackingView`: its own bottom padding,
    /// the 72pt capture button, and a gap. Keep in step with them.
    static func aboveARControls(watermarkClearance: CGFloat) -> CGFloat {
        return max(24, watermarkClearance + 12) + 72 + 12
    }
}

/// Toast modifier for easy use
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    var isSuccess: Bool = true
    var duration: TimeInterval = 2.0
    var bottomInset: CGFloat = ToastInset.standalone

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                VStack {
                    Spacer()
                    ToastView(message: message, isSuccess: isSuccess)
                        .padding(.bottom, bottomInset)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation {
                                    isPresented = false
                                }
                            }
                        }
                }
                .animation(.easeInOut(duration: 0.3), value: isPresented)
            }
        }
    }
}

extension View {
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        isSuccess: Bool = true,
        duration: TimeInterval = 2.0,
        bottomInset: CGFloat = ToastInset.standalone
    ) -> some View {
        modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            isSuccess: isSuccess,
            duration: duration,
            bottomInset: bottomInset
        ))
    }
}

#if DEBUG
struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ToastView(message: "Localization Success", isSuccess: true)
            ToastView(message: "Localization Failed", isSuccess: false)
        }
        .padding()
        .background(Color.gray)
    }
}
#endif
