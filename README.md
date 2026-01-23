# MultiSet iOS SDK

## Overview

The MultiSet iOS SDK provides Visual Positioning System (VPS) localization capabilities for iOS applications. It enables precise indoor and outdoor localization using camera-based visual recognition against pre-mapped 3D environments.

**GitHub Repository:** [https://github.com/MultiSet-AI/multiset-ios-sdk.git](https://github.com/MultiSet-AI/multiset-ios-sdk.git)

## Quick Start

### 1. Add the Framework

Add the `MultiSetSDK.xcframework` to your Xcode project:

1. Drag the `MultiSetSDK.xcframework` folder into your Xcode project navigator
2. Ensure "Copy items if needed" is checked
3. Add to your app target
4. In **Build Settings**, ensure the framework is listed under **Frameworks, Libraries, and Embedded Content** with "Embed & Sign"

### 2. Credentials Setup

Open `SDKConfig.swift` and configure your credentials:

```swift
struct SDKConfig {
    // Authentication Credentials
    static let clientId = "YOUR_CLIENT_ID"
    static let clientSecret = "YOUR_CLIENT_SECRET"

    // Map Configuration (use either mapCode OR mapSetCode)
    static let mapCode = "YOUR_MAP_CODE"
    static let mapSetCode = ""
}
```

| Property           | Description              | Required                     |
|--------------------|--------------------------|------------------------------|
| `clientId`         | Your client identifier   | Yes                          |
| `clientSecret`     | Your secret key          | Yes                          |
| `mapCode`          | Single map identifier    | One of these is required     |
| `mapSetCode`       | Map set identifier       | One of these is required     |

To obtain credentials, visit: [https://developer.multiset.ai/credentials](https://developer.multiset.ai/credentials)

### 3. Initialize the SDK

```swift
import MultiSetSDK

// Build configuration
let config = MultiSetConfig(
    clientId: clientId,
    clientSecret: clientSecret,
    mapCode: mapCode,
    localizationMode: .multiFrame,
    meshVisualization: true,
    backgroundLocalization: true
)

// Initialize SDK
MultiSet.shared.initialize(config: config, callback: self)
```

### 4. Implement Callbacks

```swift
class MyDelegate: MultiSetCallback {
    func onSDKReady() { /* SDK initialized */ }
    func onAuthenticationSuccess() { /* Ready for localization */ }
    func onAuthenticationFailure(error: String) { /* Handle error */ }
    func onLocalizationSuccess(result: LocalizationResult) { /* Handle success */ }
    func onLocalizationFailure(error: String) { /* Handle failure */ }
    func onTrackingStateChanged(state: TrackingState) { /* Handle state change */ }
    func onMeshLoaded(mapId: String) { /* Mesh loaded */ }
    func onMeshLoadError(error: String) { /* Mesh load failed */ }
}
```

### 5. Display AR View

Use the provided `MultiSetARView` SwiftUI component:

```swift
import SwiftUI
import MultiSetSDK

struct MyARView: View {
    var body: some View {
        ZStack {
            MultiSetARView()
                .ignoresSafeArea()

            // Your UI overlays here
        }
    }
}
```

### 6. Trigger Localization

```swift
// Start localization
MultiSet.shared.localize()

// Stop localization
MultiSet.shared.stopLocalization()
```

## Requirements

- iOS 16.0+
- ARKit compatible device (iPhone 6s or later)
- Camera permission
- Internet connectivity

## Info.plist Configuration

Add the following keys to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for AR localization</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access improves localization accuracy</string>
```

## License

Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. For license details, visit [www.multiset.ai](https://www.multiset.ai).
