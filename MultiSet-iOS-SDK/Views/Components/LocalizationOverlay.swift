/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// Overlay shown during frame capture with animated phone image
struct LocalizationOverlay: View {
    @State private var phoneOffset: CGFloat = 0
    let isCapturing: Bool
    let statusText: String

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Animation Container
                ZStack {
                    // Background AR image
                    Image("bg_ar")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 100)

                    // Animated phone image
                    Image("phone_image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 58, height: 77)
                        .offset(x: phoneOffset)
                }
                .frame(width: 200, height: 100)

                // Instruction text
                Text("Hold steady and scan\nyour surroundings")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(white: 0.67))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Status text
                Text(statusText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.top, 12)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }

    private func startAnimation() {
        // Animate phone left to right to left
        withAnimation(
            Animation.easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            phoneOffset = 60
        }
    }

    private func stopAnimation() {
        phoneOffset = 0
    }
}

/// API loading overlay shown while waiting for server response
struct APILoadingOverlay: View {
    var statusText: String = "Localizing..."

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#7B2CBF")))
                    .scaleEffect(1.5)

                Text(statusText)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
        }
    }
}

/// Background localization progress indicator (subtle line at bottom)
struct BackgroundProgressIndicator: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#7B2CBF")))
                .frame(height: 3)
        }
    }
}

#if DEBUG
struct LocalizationOverlay_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LocalizationOverlay(isCapturing: true, statusText: "Capturing frames...")
            APILoadingOverlay()
            BackgroundProgressIndicator()
        }
    }
}
#endif
