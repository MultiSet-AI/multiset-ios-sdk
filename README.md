# MultiSet iOS SDK

## Overview

The MultiSet iOS SDK provides Visual Positioning System (VPS) localization capabilities for iOS applications. It enables precise indoor and outdoor localization using camera-based visual recognition against pre-mapped 3D environments.

**GitHub Repository:** [https://github.com/MultiSet-AI/multiset-ios-sdk.git](https://github.com/MultiSet-AI/multiset-ios-sdk.git)

## Quick Start

### 1. Add the Framework

Add `MultiSetSDK.xcframework` to your Xcode project:

1. Drag the `MultiSetSDK.xcframework` folder into your Xcode project navigator
2. Ensure "Copy items if needed" is checked
3. Add to your app target
4. In **General > Frameworks, Libraries, and Embedded Content**, ensure it is set to **"Embed & Sign"**

### 2. Info.plist Configuration

Add the following keys to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for AR localization</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access improves localization accuracy</string>
```

### 3. Credentials Setup

Open `SDKConfig.swift` and configure your credentials:

```swift
struct SDKConfig {
    static let clientId = "YOUR_CLIENT_ID"
    static let clientSecret = "YOUR_CLIENT_SECRET"

    // Use either mapCode OR mapSetCode (not both)
    static let mapCode = "YOUR_MAP_CODE"
    static let mapSetCode = ""
}
```

| Property       | Description            | Required                 |
|----------------|------------------------|--------------------------|
| `clientId`     | Your client identifier | Yes                      |
| `clientSecret` | Your secret key        | Yes                      |
| `mapCode`      | Single map identifier  | One of these is required |
| `mapSetCode`   | Map set identifier     | One of these is required |

To obtain credentials, visit: [https://developer.multiset.ai/credentials](https://developer.multiset.ai/credentials)

### 4. Initialize the SDK

```swift
import MultiSetSDK

// Using a factory method
let config = MultiSetConfig.default(
    clientId: "YOUR_CLIENT_ID",
    clientSecret: "YOUR_CLIENT_SECRET",
    mapCode: "YOUR_MAP_CODE"
)

// Initialize
MultiSet.shared.initialize(config: config, callback: myDelegate)
```

### 5. Implement Callbacks

```swift
class MyDelegate: MultiSetCallback {
    func onSDKReady() {
        print("SDK initialized")
    }

    func onAuthenticationSuccess() {
        print("Ready for localization")
    }

    func onAuthenticationFailure(error: String) {
        print("Auth failed: \(error)")
    }

    func onLocalizationSuccess(result: LocalizationResult) {
        print("Localized at map: \(result.mapCode)")
        print("Position: \(result.position)")
        print("Confidence: \(result.confidence ?? 0)")
    }

    func onLocalizationFailure(error: String) {
        print("Localization failed: \(error)")
    }

    func onTrackingStateChanged(state: TrackingState) {
        print("Tracking: \(state)")
    }

    // Optional callbacks
    func onMeshLoaded(mapCode: String) {
        print("Mesh loaded for: \(mapCode)")
    }

    func onMeshLoadError(error: String) {
        print("Mesh error: \(error)")
    }
}
```

### 6. Display AR View

Use the provided `MultiSetARView` SwiftUI component:

```swift
import SwiftUI
import MultiSetSDK

struct MyARView: View {
    var body: some View {
        ZStack {
            MultiSetARView()
                .ignoresSafeArea()

            VStack {
                Spacer()
                Button("Localize") {
                    MultiSet.shared.localize()
                }
                .padding()
            }
        }
    }
}
```

### 7. Trigger Localization

```swift
// Start localization
MultiSet.shared.localize()

// Stop localization
MultiSet.shared.stopLocalization()
```

## Configuration Options

### Factory Methods

```swift
// Default: multi-frame with auto & background localization
let config = MultiSetConfig.default(clientId: "...", clientSecret: "...", mapCode: "...")

// Single-frame: one image, no auto/background localization
let config = MultiSetConfig.singleFrame(clientId: "...", clientSecret: "...", mapCode: "...")

// Multi-frame: explicit multi-frame mode
let config = MultiSetConfig.multiFrame(clientId: "...", clientSecret: "...", mapCode: "...")

// Continuous: aggressive re-localization (15s intervals)
let config = MultiSetConfig.continuous(clientId: "...", clientSecret: "...", mapCode: "...")
```

### Custom Configuration

```swift
var config = MultiSetConfig(
    clientId: "...",
    clientSecret: "...",
    mapCode: "..."
)

// Localization Mode
config.localizationMode = .multiFrame       // .singleFrame or .multiFrame

// Auto Localization
config.autoLocalize = true                  // Auto-start when AR begins
config.backgroundLocalization = true        // Re-localize at intervals
config.bgLocalizationDurationSeconds = 30   // Interval in seconds (15-180)
config.relocalization = true                // Re-localize on tracking loss
config.firstLocalizationUntilSuccess = true // Retry first localization until success

// Multi-Frame Capture
config.numberOfFrames = 4                   // Frames to capture (4-6)
config.frameCaptureIntervalMs = 500         // Interval between captures (300-800ms)

// Confidence Filtering
config.confidenceCheck = true               // Filter low-confidence results
config.confidenceThreshold = 0.3            // Minimum confidence (0.2-0.8)

// GPS
config.passGeoPose = true                   // Include GPS in requests
config.geoCoordinatesInResponse = true      // Get geo-coordinates in response

// Mesh & UI
config.meshVisualization = true             // Show 3D mesh after localization
config.showAlerts = true                    // Show success/failure alerts

// Image Quality
config.imageQuality = 90                    // JPEG quality (50-100)
```

### Using Map Sets

For multi-map environments, use `mapSetCode` instead of `mapCode`:

```swift
var config = MultiSetConfig(
    clientId: "...",
    clientSecret: "..."
)
config.mapSetCode = "YOUR_MAP_SET_CODE"
```

## Support

For technical support, visit: [https://developer.multiset.ai/support](https://developer.multiset.ai/support)

## License

Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. For license details, visit [www.multiset.ai](https://www.multiset.ai).
