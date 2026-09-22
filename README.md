# MultiSet iOS SDK

The MultiSet iOS SDK provides Visual Positioning System (VPS) localization and object tracking for
iOS apps. It localizes the device against pre-mapped 3D environments from camera images and aligns
AR content to the real world.

**GitHub Repository:** [https://github.com/MultiSet-AI/multiset-ios-sdk.git](https://github.com/MultiSet-AI/multiset-ios-sdk.git)

## What's in This Repository

| Path | What it is |
|---|---|
| `MultiSetSDK.xcframework` | The SDK as a binary framework. It does not link ARKit or RealityKit |
| `MultiSet-iOS-SDK/MultiSetAR/` | The ARKit + RealityKit adapter, as source: `MultiSetARView`, mesh rendering, the two `.metal` shaders and GPS hints. Add it to your app target |
| `MultiSet-iOS-SDK/`, `MultiSet-iOS-SDK.xcodeproj` | Demo app showing localization, object tracking and every setting. It builds against the framework and the adapter above |

## Requirements

- iOS 16.0+
- Xcode 26 or later
- A device with ARKit support (A12 chip or later). ARKit does not run in the simulator

## Run the Demo App

1. Open `MultiSet-iOS-SDK.xcodeproj`.
2. Add your credentials and map code to `MultiSet-iOS-SDK/SDKConfig.swift`:

   ```swift
   struct SDKConfig {
       static let clientId = "YOUR_CLIENT_ID"
       static let clientSecret = "YOUR_CLIENT_SECRET"

       // Use either mapCode OR mapSetCode (not both)
       static let mapCode = "YOUR_MAP_CODE"
       static let mapSetCode = ""

       // Optional, for object tracking (max 10)
       static let objectCodes: [String] = []
   }
   ```

   | Property       | Description              | Required                 |
   |----------------|--------------------------|--------------------------|
   | `clientId`     | Your client identifier   | Yes                      |
   | `clientSecret` | Your secret key          | Yes                      |
   | `mapCode`      | Single map identifier    | One of these is required |
   | `mapSetCode`   | Map set identifier       | One of these is required |
   | `objectCodes`  | Objects to track         | For object tracking      |

   To obtain credentials, visit [https://developer.multiset.ai/credentials](https://developer.multiset.ai/credentials).
3. Select your development team under **Signing & Capabilities**, then run on a device.

The gear icon on the landing screen edits the localization and object-tracking settings at runtime.

## Add the SDK to Your App

### 1. Add the Framework and the Adapter

1. Drag `MultiSetSDK.xcframework` into your Xcode project, with **Copy items if needed** checked.
2. Select your app target → **General → Frameworks, Libraries, and Embedded Content**, and set
   `MultiSetSDK.xcframework` to **Embed & Sign**.
3. Drag the `MultiSet-iOS-SDK/MultiSetAR` folder into your project with **your app target
   checked**. Check that both `.metal` files appear under **Build Phases → Compile Sources**.

### 2. Info.plist Configuration

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for AR localization</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access improves localization accuracy</string>
```

### 3. Implement the Callback

```swift
import MultiSetSDK

final class MySDKDelegate: MultiSetCallback {
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

    // The server returned a pose, but it contradicts the device's own motion, so the SDK
    // discarded it and left the AR scene untouched. See "False Positive Filtering".
    func onLocalizationFalsePositive(info: FalsePositiveInfo) {
        print("Discarded: \(info.summary)")
    }

    func onMeshLoaded(mapCode: String) {
        print("Mesh loaded for: \(mapCode)")
    }

    func onMeshLoadError(error: String) {
        print("Mesh error: \(error)")
    }
}
```

### 4. Initialize the SDK

```swift
let config = MultiSetConfig.default(
    clientId: "YOUR_CLIENT_ID",
    clientSecret: "YOUR_CLIENT_SECRET",
    mapCode: "YOUR_MAP_CODE"
)

MultiSet.shared.initialize(config: config, callback: myDelegate)
```

### 5. Display the AR View

`MultiSetARView` comes from the `MultiSetAR` folder, not from the framework.

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

### 6. Trigger Localization

```swift
// Start localization
MultiSet.shared.localize()

// Stop localization
MultiSet.shared.stopLocalization()
```

## Upgrading from 1.16.0

In 2.0 the ARKit and RealityKit code moved out of the framework and into the `MultiSetAR` folder,
which you now compile into your app.

| Your app today | Do this |
|---|---|
| Uses `MultiSetARView()` | Replace the framework and add the `MultiSetAR` folder to your app target. No code changes |
| Uses its own `ARView` with `setARSession`, `setParentEntity`, `setObjectTrackingRootEntity` | Replace the framework and add the `MultiSetAR` folder. No code changes |
| Sets `passGeoPose = true` without `MultiSetARView` | Add the folder, then call `MultiSet.shared.setGeoHintProvider(CoreLocationGeoHintProvider())` after `initialize` |

- **What breaks.** References qualified with the module name, such as `MultiSetSDK.MultiSetARView`,
  no longer compile. Mixing a 1.16.0 `MultiSetSDK.xcframework` with the new folder makes
  `MultiSetARView` ambiguous; replace both together.
- **`GeoCoordinates.altitude` is optional** (`Double?`) and is height above the WGS84 ellipsoid.
  Code that reads it as a `Double` needs unwrapping. In results it is `nil` when the server sent
  no height; 1.16.0 reported `0`.
- **Main-actor isolation.** `MultiSet` and `MultiSetCallback` are now `@MainActor`:
  - Calling `MultiSet.shared` from a synchronous context that is not on the main actor no longer
    compiles. Examples are a background queue or a nonisolated delegate method. Move the call
    into `DispatchQueue.main.async { }` or `Task { @MainActor in }`.
  - A class that adopts `MultiSetCallback` in its declaration is inferred `@MainActor`, so create
    it on the main thread. `@StateObject` and `@ObservedObject` already do.
- **`poseConsistencyCheck` now defaults to `false`.** In 1.16.0 the false-positive gate was on by
  default. If you relied on it, set `config.poseConsistencyCheck = true` explicitly — otherwise
  every response the server returns is applied, including ones that teleport the scene. This is a
  silent change: nothing fails to compile.
- **Behaviour changes.** Everything else in `MultiSetCallback` behaves as in 1.16.0. These differ:
  - The location permission prompt appears when `MultiSetARView` is created (or a geo-hint
    provider is attached), not at sign-in.
  - `onTrackingStateChanged` no longer fires a synthetic `.paused` when the view is created; the
    first call is ARKit's first real state change. It is now delivered synchronously.
  - The built-in gizmo moves before `onLocalizationSuccess` fires, not after.
  - Calling `setGizmoUpdateHandler` no longer disconnects `MultiSetARView`'s own gizmo.
  - With `passGeoPose = true` and no geo-hint provider attached, no `geoHint` is sent and the SDK
    logs a warning once.
  - `geoHint` altitude is now ellipsoidal (1.16.0 sent CoreLocation's mean-sea-level `altitude`). A fix
    without a valid altitude sends `latitude,longitude` only and turns on `use2DFiltering` for
    that request.
  - The false-positive check is now a vote across query viewpoints rather than a single distance
    threshold, and it can correct a wrong anchor by itself. See "False Positive Filtering".
  - `poseConsistencyThreshold` is a flat distance limit in metres (1-15, default 4), not a ceiling
    on a tolerance that widened with time, and its range has narrowed. A 1.16.0 value above 15 is
    clamped. The heading limit is the new `poseConsistencyYawThreshold` (5-60, default 25).
  - `GateTuning` lost `rejectionBaseM`, `rejectionMaxM`, `driftRateMPerSec`, `rejectionBaseDeg`,
    `rejectionMaxDeg` and `driftRateDegPerSec`, replaced by `rejectionDistanceM` and
    `rejectionYawDeg`. Code that set any of the six no longer compiles.
  - The radial reveal centres on the camera position when the mesh arrives, not when its download
    started.
  - With no mesh renderer attached, meshes are not downloaded and `onObjectMeshLoaded` does not
    fire.
  - Every callback arrives on the main thread. In 1.16.0, `onLocalizationFailure` could arrive on a
    background thread after a network error or when no frame was captured.
  - After a failed localization request, background localization retries after
    `bgLocalizationDurationSeconds`. In 1.16.0 the retry was scheduled off the main run loop and never
    fired.
  - `stopLocalization()` and `stopObjectTracking()` also cancel a pending retry or delayed capture.
    In 1.16.0, a retry already scheduled could still start a new request after the stop.
  - The object-tracking outline now matches the MultiSet app: a thin animated purple outline
    instead of a glowing shell. On iOS 16 and 17 it is an outline too; in 1.16.0 the shell covered
    the whole object there.
  - Map and object meshes no longer freeze the AR view while they load. Two tracked objects whose
    meshes arrive together now both render; in 1.16.0 the second one could be dropped.
  - Unchanged on purpose: `onMeshLoaded` still fires after every accepted fix, whether or not a
    mesh was drawn.

## Configuration Options

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

// Pose Consistency (false-positive gate)
config.poseConsistencyCheck = true          // Discard poses that contradict AR tracking
config.poseConsistencyThreshold = 4         // Distance limit in metres (1-15)
config.poseConsistencyYawThreshold = 25     // Heading limit in degrees (5-60)

// API Environment
config.baseURL = MultiSetConfig.productionBaseURL  // Override to target another deployment

// GPS
config.passGeoPose = true                   // Include GPS in requests
config.geoCoordinatesInResponse = true      // Get geo-coordinates in response

// Mesh & UI
config.meshVisualization = true             // Show 3D mesh after localization
config.showAlerts = true                    // Show success/failure alerts

// Image Quality
config.imageQuality = 90                    // JPEG quality (50-100)
```

### Query Mode (single-frame only)

Single-frame localization can run against either matching pipeline:

```swift
config.queryMode = .vps1   // default — standard matching, fastest response
config.queryMode = .vps2   // deep search — slower, better in hard or sparsely mapped areas
```

Or change it on an initialized SDK:

```swift
MultiSet.shared.setQueryMode(.vps2)
```

Multi-frame localization always uses VPS-1, so this value is not sent in `.multiFrame` mode.

### Using Map Sets

For multi-map environments, use `mapSetCode` instead of `mapCode`:

```swift
let config = MultiSetConfig(
    clientId: "...",
    clientSecret: "...",
    mapSetCode: "YOUR_MAP_SET_CODE"
)
```

## False Positive Filtering

A confidence score cannot catch every bad match. In a space with repeated geometry — similar
corridors, aisles, stairwells — the server can return a confident pose that belongs to a
*different* part of the map. Applied blindly, that pose teleports the whole scene.

`poseConsistencyCheck` (**off by default**) catches those using the device itself. Every fix in one AR
session measures the same map-to-session transform, so fixes taken minutes and metres apart should
still agree on where the map sits.

- **The first fix sets the anchor.** A multi-frame fix starts out trusted; a single-frame fix
  starts out provisional until another viewpoint agrees with it.
- **Later fixes are checked against it.** A response that agrees with the anchor refines it. A
  response that disagrees only moves the scene once enough separated viewpoints agree with it
  instead. `onLocalizationCorrected(from:to:trust:)` then fires alongside
  `onLocalizationSuccess`, so you can re-place any content you anchored in world space yourself.
- **Anything else is discarded.** The gizmo, the mesh and the last accepted result are left
  untouched, and `onLocalizationFalsePositive(info:)` fires instead of `onLocalizationSuccess` or
  `onLocalizationFailure`.

It is off by default because the gate *discards* responses: in a space whose thresholds it has
not been calibrated for, it costs you successful localizations. Turn it on once you have watched
the `Pose consistency ACCEPT` log lines for that space and confirmed the limits fit.

`FalsePositiveInfo` explains the decision. `jumpMeters` and `yawDeltaDeg` say how far off the
response was, measured against **two independent tolerances**: `thresholdMeters` for distance and
`thresholdDegrees` for heading. `summary` is a one-line log string.

Read `disagreement` and `cause` before quoting any of those numbers at a user:

| Field | Values | Why it matters |
|---|---|---|
| `disagreement` | `.distance`, `.heading`, `.both` | Which tolerance was broken. A response can sit well inside `thresholdMeters` and still be refused on heading — reporting the distance alone then contradicts itself |
| `cause` | `.insufficientViewpoints`, `.anchorHeldVote`, `.inlierMargin` | Why the contest was lost. On `.anchorHeldVote` the response had every viewpoint it needed and still lost on a tie, so quoting `challengerSupport` against `requiredSupport` reads as the bar being met and the pose refused anyway |

`rejection` says what to tell the user:

| `info.rejection` | Meaning | What to do |
|---|---|---|
| `.falsePositive` | The response contradicts an anchor that AR tracking still vouches for | Ask the user to localize again from somewhere more distinctive |
| `.reestablishing` | AR tracking was interrupted, and the SDK is collecting a fix to re-anchor | Nothing; not worth showing |
| `.suspectedAliasing` | The server keeps matching a structurally identical part of the space | Localizing again will not help. Offer a reset |

```swift
config.poseConsistencyCheck = true        // off by default
config.poseConsistencyThreshold = 4       // distance limit, metres, 1-15
config.poseConsistencyYawThreshold = 25   // heading limit, degrees, 5-60
```

The two limits are applied **flat** and independently — a response can sit well inside the
distance limit and still be refused on heading, which is the signature of an identical-corridor
match. What you configure is what the gate applies and what `thresholdMeters` / `thresholdDegrees`
report, so both are safe to show a user next to the setting they chose.

Every other internal is reached through `poseConsistencyTuning`. Leave it `nil` for the shipped
defaults, which is the right answer unless you are calibrating against your own logs:

```swift
var tuning = GateTuning()
tuning.agreementRadiusM = 1.5        // when two fixes count as the same vote
tuning.agreementYawDeg = 10.0
tuning.viewpointSeparationM = 1.5    // when two queries count as separate viewpoints
config.poseConsistencyTuning = tuning
```

`poseConsistencyThreshold` and `poseConsistencyYawThreshold` still win over
`GateTuning.rejectionDistanceM` and `rejectionYawDeg`.

`MultiSet.shared.anchorTrust` (`.provisional`, `.corroborated`, `.trusted`) reports how well the
current anchor is corroborated, and `onAnchorTrustChanged(_:)` fires when it changes. Wire
`MultiSet.shared.resetPoseConsistencyReference()` to your "reset" control: the next fix after it
is accepted unchecked and becomes the new anchor.

**When the *first* fix is the false positive**, that is not enough. It bootstraps the anchor
unchecked and, from a MultiFrame request, does so as `.trusted` — so every correct response
afterwards is the one reported through `onLocalizationFalsePositive`, and localizing again only
earns another rejection. Nothing the gate can observe separates that from the healthy case.
`MultiSet.shared.resetSession()` is the exit: it stops localization and tracking, removes every
mesh, drops the gate's reference and restarts the frame source's world origin. Credentials and
authentication survive, so call `localize()` when ready rather than initializing again. Offer it
from your false-positive UI, not just from a toolbar.

For maps with repeated structure, such as identical corridors or mirrored floors, raise the
agreement a correction needs for that map:

```swift
config.mapAliasingRisk = ["YOUR_MAP_CODE": 1.5]
```

## Threading

`MultiSet` and `MultiSetCallback` are isolated to the main actor.

- **Callbacks.** Every `MultiSetCallback` method is called on the main thread. Update UI and
  `@Published` state directly; there is no need for `DispatchQueue.main.async`.
- **Calling the SDK.** Call `MultiSet.shared` from the main thread. SwiftUI views and UIKit view
  controllers already run there. From a background task, `await` the call instead, as in
  `await MultiSet.shared.localize()`.
- **Blocking work.** Network requests and mesh file reads and writes run off the main thread. The
  `MultiSetAR` mesh renderers also parse GLBs off the main thread, so the AR view keeps rendering
  while a map or object mesh loads.

## Session Length and Token Renewal

Access tokens issued by the MultiSet API are short-lived (minutes, not hours). The SDK renews them
for you: it reads each token's own lifetime, refreshes ahead of expiry, and if a request is ever
rejected with HTTP 401 it refreshes once and replays that request automatically. Concurrent
requests share a single renewal rather than each triggering their own.

Nothing is required of your app — sessions of any length work without re-initializing. Two
consequences worth knowing:

- `MultiSet.shared.authToken` changes during a session. Read it at the point of use and never
  cache it.
- If renewal ultimately fails (for example, credentials revoked mid-session) the error surfaces
  through the operation that was in flight — `onLocalizationFailure` or `onObjectTrackingFailure`
  — with the authentication error in its message. `MultiSet.shared.isAuthenticated` remains
  `true`.

## Pointing at a Different API Environment

The SDK ships as a binary framework, so its endpoints are not editable. Set the host through the
config instead — every endpoint the SDK calls is derived from it:

```swift
var config = MultiSetConfig.default(
    clientId: "...",
    clientSecret: "...",
    mapCode: "..."
)
config.baseURL = "https://staging-api.multiset.ai"   // no trailing slash needed

MultiSet.shared.initialize(config: config, callback: myDelegate)

print(MultiSet.shared.activeBaseURL)   // what requests actually go to
```

- Applied by `initialize(...)`, **before** authentication. An access token is only valid against
  the host that issued it, so `updateConfig(...)` deliberately ignores a changed `baseURL` (it logs
  when it does). To switch environments at runtime, call `release()` and then `initialize(...)`
  again.
- Credentials are per environment — change `clientId` / `clientSecret` together with the host.
- Trailing slashes and surrounding whitespace are trimmed. A value that is empty or is not an
  `http`/`https` URL with a host is refused with a log line, and the previous host stays in use,
  so a typo cannot silently take the SDK offline.
- `MultiSetConfig.productionBaseURL` is the default value, if you need to name it.

## Using Your Own ARView

With the `MultiSetAR` folder in your target, the SDK attaches to an `ARView` you create yourself,
through the same calls as 1.16.0:

```swift
MultiSet.shared.setARSession(arView.session)
MultiSet.shared.setParentEntity(mapAnchor)                 // map meshes are parented here
MultiSet.shared.setObjectTrackingRootEntity(objectAnchor)  // object meshes, world-fixed
MultiSet.shared.setGizmoUpdateHandler { position, rotation in
    mapAnchor.transform.translation = position
    mapAnchor.transform.rotation = rotation
}
```

Call these after `initialize(config:callback:)`. The SDK moves nothing itself on this path; your
handler moves `mapAnchor`. Call `MultiSet.shared.setARSession(nil)` when your `ARView` goes away;
the SDK shows its watermark for as long as a session is attached.

If your app sets its own `ARSessionDelegate`, forward tracking from it, or interruption and
relocalization stop reaching the SDK: call `MultiSet.shared.forwardARTrackingState(camera.trackingState)`
in `session(_:cameraDidChangeTrackingState:)`, and `MultiSet.shared.notifyTrackingInterrupted()` in
`sessionWasInterrupted(_:)` and `sessionInterruptionEnded(_:)`.

**You also have to handle a relocalization that never finishes.** When the app is backgrounded and
the device is carried somewhere else, ARKit resumes into `.limited(.relocalizing)` with nothing left
to match against, and stays there — it does not time out on its own. The SDK cannot capture a frame
in that state, so every localization fails on "no frames captured" and your UI sits on a spinner.

`ARSessionController` in `MultiSetAR/` solves this and is worth copying: it lets ARKit attempt
relocalization, but starts a watchdog on `sessionInterruptionEnded(_:)` and, if tracking has not
returned to `.normal` within 6 seconds, runs the configuration again with `.resetTracking` and calls
`MultiSet.shared.notifyWorldOriginReset()`. That last call matters — a new world frame invalidates
the anchor the pose gate is holding, and without it the gate compares offsets across two different
coordinate systems.

## Custom AR Runtimes

The framework has no ARKit dependency. To drive it from another runtime, implement
`MultiSetFrameSource` and attach it after `initialize(config:callback:)`:

```swift
final class MyFrameSource: MultiSetFrameSource {
    @MainActor func acquireFrame() async -> CameraFrame? {
        // Build a CameraFrame from the raw camera image, camera-to-world transform, intrinsics,
        // interface orientation and monotonic timestamp. Do not correct for portrait.
        return nil
    }

    var isHostActive: Bool {
        true
    }

    @MainActor func resetWorldOrigin() {
        // Restart your tracker from a fresh world origin. Optional: the default is a no-op.
    }
}

MultiSet.shared.setFrameSource(MyFrameSource())
```

Detach it with `setFrameSource(nil)` when your AR screen closes. The watermark stays up for as
long as a frame source is attached.

- **Conventions.** Poses are right-handed, +Y up and gravity-aligned, with the camera looking down
  −Z, in metres. `timestamp` must come from a monotonic clock, never `Date()`.
- **Foreground.** Return `false` from `isHostActive` while your app is not in the foreground.
  Scheduled localization and re-tracking wait for it rather than capturing in the background.
- **Reset.** `resetWorldOrigin()` defaults to a no-op, so an existing frame source still compiles.
  Implement it wherever your tracker can restart: without it `resetSession()` drops everything the
  SDK holds but leaves the world frame the discarded pose was measured in.
- **Tracking signals.** Report tracking through three calls:
  - `notifyTrackingInterrupted()` for recoverable loss.
  - `notifyWorldOriginReset()` when the world frame is replaced.
  - `reportTrackingState(_:)` for every tracking-quality change.

  `MultiSetAR/ARTrackingSignals.swift` shows the ARKit mapping.
- **Optional receivers.** Attach a `MultiSetPoseSink` for accepted poses, a `MultiSetMeshRenderer`
  to draw the downloaded GLB meshes, and a `MultiSetGeoHintProvider` to supply GPS for
  `passGeoPose`. Meshes are not downloaded while no renderer is attached.
- **Geo-hint altitude.** The API expects heights above the WGS84 ellipsoid, not mean sea level.
  From CoreLocation, pass `ellipsoidalAltitude` rather than `altitude`. Pass `nil` when
  `verticalAccuracy` is negative: the SDK then sends latitude and longitude only, with
  `use2DFiltering` on for that request.

```

## Best Practices

1. **Wait for authentication.** Don't call `localize()` until `onAuthenticationSuccess()` is
   received.
2. **Check tracking state.** Enable the localize button only when the tracking state is
   `.tracking`.
3. **Handle failures.** Implement proper error handling in `onLocalizationFailure()`.
4. **Release resources.** Call `MultiSet.shared.release()` when done.
5. **GPS for large areas.** Enable `passGeoPose` for outdoor or large indoor spaces.

## Support

For technical support, visit: [https://developer.multiset.ai/support](https://developer.multiset.ai/support)

## License

Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. For license details, visit [www.multiset.ai](https://www.multiset.ai).
