# MultiSet-iOS-SDK

This SDK allows you to perform Visual Positioning using MultiSet's VPS (Visual Positioning System). It supports localization of either a single map or a mapSet.

## 🚀 Getting Started

### 1. Configure SDK Credentials

Open the `SDKConfig.swift` file and provide your **Client ID** and **Client Secret**:

```swift
static let clientId = "YOUR_CLIENT_ID"
static let clientSecret = "YOUR_CLIENT_SECRET"
```

To get your credentials, visit:
🔗 https://developer.multiset.ai/credentials

These credentials are required to authenticate the user with the MultiSet platform.

### 2. Choose Map Type & Provide Map Code

Depending on whether you want to localize a single map or a map set, provide the appropriate code in `SDKConfig.swift`:

```swift
// For localizing a single map
static let mapCode = "YOUR_MAP_CODE"

// For localizing a map set
static let mapSetCode = "YOUR_MAPSET_CODE"
```

Only one should be active at a time — either mapCode or mapSetCode.

Also update the selected map type in `ContentView.swift`:

```swift
@State private var selectedMapType: MapType = .map // or .mapSet

enum MapType {
    case map
    case mapSet
}
```

### 3. Start Localization

After configuration:
1. Run the app.
2. Tap the Localize button to start localization.

Upon successful localization, a Gizmo will appear at the Map Origin indicating that the pose has been correctly estimated.

## 📌 Notes

- Ensure your device has camera permissions enabled.
- The SDK uses the following endpoints:
  - Auth: https://api.multiset.ai/v1/m2m/token
  - Query: https://api.multiset.ai/v1/vps/map/query-form
- If neither mapCode nor mapSetCode is set, localization will not proceed.

## 🧑‍💻 Support

For any questions or issues, please contact support via https://docs.multiset.ai or raise an issue on this repository.
