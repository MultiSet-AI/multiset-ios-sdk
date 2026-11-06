# MultiSet iOS SDK

The MultiSet iOS SDK provides Visual Positioning System (VPS) localization, object tracking and map
creation for iOS apps. It localizes the device against pre-mapped 3D environments from camera
images and aligns AR content to the real world, and it can scan a space and upload it to be built
into a new map.

**GitHub Repository:** [https://github.com/MultiSet-AI/multiset-ios-sdk.git](https://github.com/MultiSet-AI/multiset-ios-sdk.git)

## What's in This Repository

| Path | What it is |
|---|---|
| `MultiSetSDK.xcframework` | The SDK as a binary framework. It does not link ARKit or RealityKit |
| `MultiSet-iOS-SDK/MultiSetAR/` | The ARKit + RealityKit adapter, as source: `MultiSetARView`, mesh rendering, the three `.metal` shaders, GPS hints, and `Mapping/` for map creation. Add it to your app target |
| `MultiSet-iOS-SDK/`, `MultiSet-iOS-SDK.xcodeproj` | Demo app showing localization, object tracking, map creation and every setting. It builds against the framework and the adapter above |

## Requirements

- iOS 16.0+
- Xcode 26 or later
- A device with ARKit support (A12 chip or later). ARKit does not run in the simulator
- Map creation: any device above for a Posed RGB scan; a LiDAR scan also needs the LiDAR scanner
  (iPhone 12 Pro or a later Pro model, iPad Pro 2020 or later)

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
   | `mapCode`      | Single map identifier    | For localization, one of these |
   | `mapSetCode`   | Map set identifier       | For localization, one of these |
   | `objectCodes`  | Objects to track         | For object tracking      |

   Map creation needs only the credentials. To fetch tokens from your own server instead, set
   `tokenServerURL` and leave the credentials as they are; see
   [SERVER_AUTH_GUIDE.md](SERVER_AUTH_GUIDE.md).

   To obtain credentials, visit [https://developer.multiset.ai/credentials](https://developer.multiset.ai/credentials).
3. Select your development team under **Signing & Capabilities**, then run on a device.

The gear icon on the landing screen edits the localization and object-tracking settings at runtime.
The **Mapping** card scans a space into a new map — on a LiDAR device choose **LiDAR** or
**Non-LiDAR**, on any other device it scans Non-LiDAR — and **Draft Maps** lists scans that have
not been uploaded yet. The demo's screens call the Posed RGB scan (`.posedRGB`) "Non-LiDAR".

On the AR screens, the small card at the top left shows each run's steps — capturing, uploading,
waiting on the server, then a tick or a red mark — and a bar at the bottom left shows a map or
object mesh while it loads. See "Showing a Run's Progress".

## Add the SDK to Your App

### 1. Add the Framework and the Adapter

1. Drag `MultiSetSDK.xcframework` into your Xcode project, with **Copy items if needed** checked.
2. Select your app target → **General → Frameworks, Libraries, and Embedded Content**, and set
   `MultiSetSDK.xcframework` to **Embed & Sign**.
3. Drag the `MultiSet-iOS-SDK/MultiSetAR` folder into your project with **your app target
   checked**. Check that all three `.metal` files appear under **Build Phases → Compile Sources**.
   `MultiSetAR/Mapping/` is needed only for map creation; nothing else in the folder depends on it.

### 2. Info.plist Configuration

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is used to determine your position and to scan spaces into maps</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access is used to improve localization accuracy and to record where a map was scanned</string>
```

Location is optional: without it, localization sends no `geoHint` and a scanned map carries no
coordinates.

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

    // The scene is being re-aligned after a tracking break. See
    // "Retries, Refreshes and Tracking Recovery".
    func onRecoveryPhaseChanged(_ phase: RecoveryPhase, needsRealignment: Bool) {
        print("Recovery: \(phase), hide content: \(needsRealignment)")
    }

    // A run moved between capturing, uploading and waiting on the server.
    // See "Showing a Run's Progress".
    func onLocalizationStageChanged(_ stage: LocalizationStage, isBackground: Bool) {
        print("Stage: \(stage)")
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

A secret in your app can be read by anyone who unpacks it. To keep it on your own server, see
[Keeping the Client Secret on Your Server](#keeping-the-client-secret-on-your-server).

A config with credentials and no map or object codes is valid, for an app that only creates maps.
`localize()` then reports `Missing mapCode or mapSetCode` through `onLocalizationFailure`, and
`startObjectTracking()` reports `Missing objectCodes` through `onObjectTrackingFailure`.

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

## Upgrading from 2.1

Replace `MultiSetSDK.xcframework`. The `MultiSetAR` folder is unchanged from 2.1.0, and no code
changes are needed.

- **New and optional: a token provider.** `MultiSetConfig(credentials: .tokenProvider(_:), ...)`
  gets access tokens from your own server, so the client secret stays off the device. See
  "Keeping the Client Secret on Your Server".
- **`onAuthenticationFailure(error:)` receives the actual reason**, such as
  `Authentication failed: HTTP 401 ...`. In 2.1 it always received `Ready to authenticate`.

## Upgrading from 2.0

Replace `MultiSetSDK.xcframework` and the `MultiSetAR` folder together. There are no breaking API
changes, and if you do not create maps no code changes are needed. Two behaviours differ:

- **`initialize(config:callback:)` accepts a config with credentials only.** In 2.0 it refused one
  with no `mapCode`, `mapSetCode` or `objectCodes` through `onAuthenticationFailure`. The SDK now
  authenticates, and `localize()` or `startObjectTracking()` reports the missing code when called.
- **`bgLocalizationDurationSeconds` accepts 10–180 seconds** (2.0: 15–180).

- **A failed first fix is retried at most 5 times**, then reported through
  `onLocalizationFailure`. A retry follows 0.5 s after a miss, and 4, 8 or 12 s after a timeout or
  a server error. The first tracked object follows the same rule.
- **Recovery after a tracking break waits for normal tracking.** With `relocalization` on, the SDK
  re-localizes once ARKit tracks normally again, hides the map mesh until that fix lands, and
  reports neither its runs nor their misses as failures.
- **`MultiSetARView` starts a fresh world frame when the app returns from the background**, instead
  of resuming the old one, and re-localizes and re-tracks in it. Object outlines stay hidden until
  their object is tracked again. If you run your own `ARView`, see "Using Your Own ARView".
- **`queryMode` applies to multi-frame localization too**, which now supports `.vps2`.

New and optional: `onRecoveryPhaseChanged(_:needsRealignment:)`,
`onLocalizationStageChanged(_:isBackground:)`, `onObjectTrackingStageChanged(_:isBackground:)`, the
`localizationStage`, `objectTrackingStage`, `recoveryPhase`, `needsRealignment`, `isLoadingMapMesh`
and `isLoadingObjectMesh` properties, and `MultiSetMeshRenderer.setMapMeshVisible(_:)`, which a
custom renderer may implement. All of them have defaults, so existing code compiles unchanged.

To add map creation, follow "Map Creation" below.

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

// Matching pipeline, for single-frame and multi-frame queries alike
config.queryMode = .vps1                    // .vps1 (default) or .vps2

// Auto Localization
config.autoLocalize = true                  // Auto-start when AR begins
config.backgroundLocalization = true        // Re-localize at intervals
config.bgLocalizationDurationSeconds = 30   // Interval in seconds (10-180)
config.relocalization = true                // Re-localize on tracking loss
config.firstLocalizationUntilSuccess = true // Retry a failed first fix silently, up to 5 times

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

### Query Mode

Localization can run against either matching pipeline, in both single-frame and multi-frame mode:

```swift
config.queryMode = .vps1   // default — standard matching, fastest response
config.queryMode = .vps2   // deep search — slower, better in hard or sparsely mapped areas
```

Or change it on an initialized SDK:

```swift
MultiSet.shared.setQueryMode(.vps2)
```

The value is sent with every localization query, single-frame and multi-frame.

### Using Map Sets

For multi-map environments, use `mapSetCode` instead of `mapCode`:

```swift
let config = MultiSetConfig(
    clientId: "...",
    clientSecret: "...",
    mapSetCode: "YOUR_MAP_SET_CODE"
)
```

## Retries, Refreshes and Tracking Recovery

**First fix.** With `firstLocalizationUntilSuccess` (default on), a failed first localization is
retried silently up to 5 times before `onLocalizationFailure` reports it. A retry follows 0.5 s
after a miss, or 4 s, 8 s, then 12 s after a timeout or a server error, so a busy server is not
asked twice at once. `isLocalizing` and `isShowingOverlay` stay true through each wait, and
`localize()` is refused meanwhile. The rule covers the first fix of each session: after
`initialize`, after `resetSession()`, and each time a new AR view attaches.
`firstObjectTrackingUntilSuccess` follows the same rule for the first tracked object.

**Background refresh.** With `backgroundLocalization` on, the next refresh is armed after every
run, `bgLocalizationDurationSeconds` later. Switching it through `updateConfig(_:)` takes effect
at once: on after a fix arms a refresh, off cancels the one armed. A missed refresh is reported
through `onLocalizationFailure` and waits the full interval before the next.

**Recovery after a tracking break.** With `relocalization` (default on), a break after a fix is
recovered without a tap. The SDK waits for normal tracking, lets it settle for 1 s, then
re-localizes, and retries every second until a fix lands. Recovery runs show no overlay and
never call `onLocalizationFailure`; the fix that lands calls `onLocalizationSuccess` as usual.
Nothing is recovered before the first fix. With `relocalization` off, the last fix stays applied
and only a tap or a background refresh corrects it.

| Break | Scene out of place |
|---|---|
| Session interrupted, app sent to the background, ARKit relocalizing | At once |
| A new world frame (`notifyWorldOriginReset()`) | At once |
| Any other limited tracking (fast motion, too little detail) | After 2 s |

Content placed in the map frame sits where the room no longer is while the scene is out of place.
The SDK hides the map mesh for that time through `MultiSetMeshRenderer.setMapMeshVisible(_:)`,
which `MultiSetARView` implements apart from `setMeshVisible(_:)`, so neither undoes the other.
Hide your own content until the recovery lands:

```swift
func onRecoveryPhaseChanged(_ phase: RecoveryPhase, needsRealignment: Bool) {
    contentRoot.isEnabled = !needsRealignment
    switch phase {
    case .none: statusLabel.text = nil
    case .waitingForTracking: statusLabel.text = "Waiting for tracking…"
    case .realigning: statusLabel.text = "Re-aligning scene…"
    }
}
```

`MultiSet.shared.recoveryPhase` and `MultiSet.shared.needsRealignment` hold the same state.

**Tracked objects after a break.** Object outlines are hidden while ARKit relocalizes after an
interruption (the app sent to the background included), and shown again once it relocalizes. If
it cannot and a new world frame starts, each outline stays hidden until that object is tracked
again. With `restartObjectTracking` (default on), the SDK re-tracks once tracking has been normal
for 1 s; a miss from that run is not reported.

## Showing a Run's Progress

Each localization and object tracking run reports where it stands, so a host can show more than
a spinner. `onLocalizationStageChanged(_:isBackground:)` and
`onObjectTrackingStageChanged(_:isBackground:)` (both optional) fire on every change:

| Stage | Meaning |
|---|---|
| `.capturing(captured:required:)` | Frames are being taken. For object tracking this covers `objectTrackingCaptureDelay`. |
| `.uploading` | The query is going out. A fixed step of up to 2 s: the request reports no progress. |
| `.awaitingResponse` | The query is sent and the server is searching. |
| `.idle` | The run ended. Its result arrives through the usual success, failure or false-positive callback. |

`isBackground` is true for a background refresh, a recovery, a background re-track and a restart
after a tracking loss: show those without covering the scene. A run that is retried silently goes
back to `.idle` between attempts while `isShowingOverlay` stays true.

```swift
func onLocalizationStageChanged(_ stage: LocalizationStage, isBackground: Bool) {
    switch stage {
    case .capturing(let captured, let required): statusLabel.text = "Capturing \(captured) of \(required)"
    case .uploading: statusLabel.text = "Uploading…"
    case .awaitingResponse: statusLabel.text = "Matching against the map…"
    case .idle: statusLabel.text = nil
    @unknown default: statusLabel.text = nil
    }
}
```

`LocalizationStage` may gain cases in a later release, so a `switch` over it needs
`@unknown default`. `MultiSet.shared.localizationStage` and `objectTrackingStage` hold the same
state.

A mesh arrives after the fix that asked for it. `MultiSet.shared.isMapMeshLoading` and
`isObjectMeshLoading` (from the `MultiSetAR` folder) are true from the moment it is fetched until it
is in the AR scene; the framework's own `isLoadingMapMesh` and `isLoadingObjectMesh` cover the fetch
alone. A fix on a map whose mesh is already in the scene does not turn them on. The demo app's
`RunStatusCard`, `FrameCaptureOverlay` and `MeshLoadingBar` (`MultiSet-iOS-SDK/Views/Components/`)
show all of this.

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

## Keeping the Client Secret on Your Server

Instead of `clientId` and `clientSecret`, give the SDK a token provider. Your server keeps the
secret, gets MultiSet access tokens, and hands them to the app; the SDK sends that token on every
API call and asks for a new one when it needs to. [SERVER_AUTH_GUIDE.md](SERVER_AUTH_GUIDE.md)
walks through both sides, with a server example.

```swift
let provider = ClosureTokenProvider { reason in
    try await MyBackend.multiSetToken(skipCache: reason == .rejected)
}

var config = MultiSetConfig(credentials: .tokenProvider(provider), mapCode: "YOUR_MAP_CODE")
config.localizationMode = .multiFrame   // every other setting starts at its default

MultiSet.shared.initialize(config: config, callback: myDelegate)
```

Your server gets each token the way the SDK otherwise would, from the environment `baseURL`
points at:

```bash
curl -X POST https://api.multiset.ai/v1/m2m/token -u "$CLIENT_ID:$CLIENT_SECRET"
# {"token": "<JWT>", "expiresOn": "..."}
```

Notes:

- The provider is asked with a reason: `.initial` from `initialize(...)`, `.expiring` before the
  current token runs out, and `.rejected` after the API refused it with a 401. On `.rejected`,
  return a newly issued token, not a cached copy.
- Return only the token string: the SDK reads the expiry from the token's own `exp`, so your
  server's `expiresOn` is not needed. A 30-minute token is renewed 5 minutes before it expires.
- Your server may cache a token across devices, but should hand out a new one once the cached copy
  has under 5 minutes left. The SDK still renews a part-used token in time, just more often.
- A request refused with a 401 is retried once with the replacement. If that is refused too, the
  request fails with the 401.
- A provider that throws or returns an empty string fails `initialize(...)` through
  `onAuthenticationFailure` ("Token provider failed: ..."); later on, it fails only the request
  that needed the token.
- The provider is called on the main actor, one call at a time: await your network request
  rather than blocking. It must return or throw; `release()` cancels a call in flight.
- This keeps the secret off the device, but a token still carries your account's rights until it
  expires. Put your token endpoint behind your own sign-in.
- In the demo app, set `SDKConfig.tokenServerURL` to try it: `TokenServerProvider` expects your
  endpoint to answer `{"token": "<JWT>"}` and passes the reason as `?reason=`.

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

When your app moves to the background, pause the session and call
`forwardARTrackingState(.notAvailable)`. When it returns, start a fresh world frame
(`run(_:options: [.resetTracking, .removeExistingAnchors])`) and call `notifyWorldOriginReset()`;
the SDK re-localizes and re-tracks in it once ARKit tracks normally. Do not resume the old frame:
after the device was walked somewhere else it no longer matches the room, and a fix made in it is
moved off again. Create the `ARView` with `automaticallyConfigureSession: false` so RealityKit does
not resume it for you, do not capture `currentFrame` until a frame newer than the trip arrives, and
return `false` from `sessionShouldAttemptRelocalization(_:)` (the default) so ARKit never fits the
old frame back on after an interruption. `MultiSetAR/ARSessionController.swift` and
`ARSessionFrameSource.swift` show all of this.

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

  `MultiSetAR/ARTrackingSignals.swift` shows the ARKit mapping. A recovery after a break starts
  only when `reportTrackingState(.tracking)` follows it. Report a trip to the background as an
  interruption too, and the tracking state again once frames resume.
- **Optional receivers.** Attach a `MultiSetPoseSink` for accepted poses, a `MultiSetMeshRenderer`
  to draw the downloaded GLB meshes (implement its optional `setMapMeshVisible(_:)` to hide the map
  mesh while the scene is out of place), and a `MultiSetGeoHintProvider` to supply GPS for
  `passGeoPose`. Meshes are not downloaded while no renderer is attached.
- **Geo-hint altitude.** The API expects heights above the WGS84 ellipsoid, not mean sea level.
  From CoreLocation, pass `ellipsoidalAltitude` rather than `altitude`. Pass `nil` when
  `verticalAccuracy` is negative: the SDK then sends latitude and longitude only, with
  `use2DFiltering` on for that request.

## Map Creation

The SDK can scan a space, package the capture, keep it on the device as a draft, and upload it to
your account, where it is built into a VPS map. The capture format and the upload are inside the
framework; `MultiSetAR/Mapping/` supplies the ARKit side, and the demo app's
`MultiSet-iOS-SDK/Views/Mapping/` the screens, which you can reuse.

There are two kinds of scan (`MappingCaptureKind`):

| Kind | Records | Needs | While scanning, the screen shows |
|---|---|---|---|
| `.lidar` | Camera images, depth and a reconstructed mesh | A LiDAR scanner | The reconstructed mesh |
| `.posedRGB` | Camera images and their poses | World tracking only | ARKit's feature points, and how well tracking is going |

Both upload the same package layout; a Posed RGB package has no depth or mesh. Prefer LiDAR where
the device has it. A Posed RGB map depends on good tracking, so scan textured, well-lit spaces and
move slowly.

### Setup

1. Add `MultiSetAR/` to your target, including `Mapping/` and `Mapping/ScanMeshSurface.metal`.
2. Forward the background upload session's wake-up from your app delegate, so an upload that
   finishes while your app is not running is recorded:

   ```swift
   func application(_ application: UIApplication,
                    handleEventsForBackgroundURLSession identifier: String,
                    completionHandler: @escaping () -> Void) {
       MultiSet.shared.mapping.handleEventsForBackgroundURLSession(
           identifier: identifier, completionHandler: completionHandler)
   }
   ```

3. Scans are recorded in landscape. Return the adapter's lock from your app delegate, or the
   scan screen rotates with the device. Outside the scan screen the lock answers with the
   orientations your `Info.plist` declares, so the rest of your app is unaffected:

   ```swift
   func application(_ application: UIApplication,
                    supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
       OrientationLock.shared.mask
   }
   ```

4. Call `await MultiSet.shared.mapping.resumeUploads()` when your app becomes active, for example
   from `sceneDidBecomeActive(_:)`.

The demo app's `AppDelegate.swift` and `SceneDelegate.swift` do all three. No background mode is
needed. Scanning works before `initialize(config:callback:)`; uploading waits until the SDK is
authenticated and starts by itself once it is.

### Scanning

```swift
let source = ARMappingSource(kind: .lidar)        // or .posedRGB; owns the ARView, shown with MultiSetMappingARView
let mapping = MultiSet.shared.mapping

mapping.setSource(source)
await mapping.beginPreview()                      // camera on, nothing recorded; asks for camera access
await mapping.startScan()                         // tracking restarts; the scan's origin is here
// …the user walks the space…
let outcome = await mapping.stopScan()            // packages the scan
if outcome == .packaged {
    let draft = try mapping.saveDraft(named: "Lobby")
    await mapping.upload(draftID: draft.id)
}
mapping.endPreview()                              // when the screen goes away
```

Offer only the kinds in `MappingSupport.captureKinds`: both on a LiDAR device, `.posedRGB` alone
without one. A `.lidar` source on a device without LiDAR previews, then fails at Start with
`MappingFailure.Reason.sessionError` and a message saying why.

Scan rules the SDK enforces:

- A scan shorter than `MappingLimits.minimumScanDuration` (10 s) is discarded, and `stopScan()`
  returns `.discardedTooShort`. The SDK stops a scan at `MappingLimits.maximumScanDuration` (600 s)
  by itself.
- Starting needs about 1.5 GB of free space for a LiDAR scan and 600 MB for a Posed RGB scan.
- A map name must be at least `MappingLimits.minimumMapNameLength` (3) characters once trimmed.
- Frames too blurred to use are dropped; `scan.showsMotionWarning` turns on when the device moves
  too fast for a sharp capture.
- An interruption — a call, the app leaving the foreground — ends the scan, because tracking
  afterwards is in a different world frame. A scan past the minimum is packaged as it stood; a
  shorter one fails. `ARMappingSource` reports interruptions for you. `scan.autoStopReason` says
  why the SDK stopped a scan by itself.

The demo app keeps its stop button disabled until the 10 s minimum, so a scan cannot be thrown
away by an early tap, and shows an alert at 9:00: "One minute left — the scan stops itself at 10:00".

A Posed RGB scan adds:

- A frame is kept only when the camera has moved 5 cm or turned 5° since the last kept frame, and
  only once tracking has held for a second (two after a loss). Frames taken in the second before
  tracking is lost, or before ARKit corrects its pose in a jump, are deleted; `scan.discardedFrames`
  counts them.
- `scan.tracking` grades tracking (good, weak, lost) with the reason, and `scan.trackingAdvice`
  names a problem that has lasted, at most once every few seconds, for a toast.
- `scan.walkedArea` is the floor area the kept frames cover, once they span a metre.
- A warm device captures less often (`scan.isCapturingSlowly`). The scan stops by itself if free
  space falls below what packaging needs.
- Packaging can be stopped with `cancelPackaging()`; `resumePackaging()` starts it again and
  `discardScan()` deletes the scan.

### Observing

Read state from `MultiSet.shared.mapping` when one of these is posted on the main thread:

| Notification | Read |
|---|---|
| `.multiSetMappingScanDidChange` | `scan` — phase, elapsed time, packaging progress, frame counts, motion warning, and for Posed RGB the tracking status and advice |
| `.multiSetMappingDraftsDidChange` | `drafts()` |
| `.multiSetMappingUploadsDidChange` | `uploadState(for:)` |

A failed scan reports `MappingPhase.failed(MappingFailure)`, whose `message` is written for the
user. Call `acknowledgeFailure()` once it has been shown. `MappingPhase` and the other mapping
enums can gain cases, so a `switch` over them needs `@unknown default`.

### Drafts and uploads

- **A draft stays until an upload succeeds.** Every failure keeps the scan, so a retry never
  costs another scan.
- **The transfer runs on a background `URLSession`.** It continues when the app is backgrounded,
  locked or terminated.
- **Uploads retry by themselves.** An interrupted upload waits 5, 15, 30, 60 and 120 s between
  attempts. After that it waits for `resumeUploads()` or for the network to return.
- **`deleteDraft(id:)` removes the scan's files** and cancels its upload.
- **Files location.** Scans are stored in Application Support, not in your app's Documents
  folder, so they do not appear in the Files app.
- **The map says how it was captured.** Creating the map sends
  `"source": {"provider": "mobile", "fileType": "zip" | "PosedRGB", "coordinateSystem": "LHS"}`;
  `MappingDraft.captureKind` tells the two apart.

### Custom runtimes

To scan with something other than ARKit, implement `MultiSetMappingSource`. A `.lidar` source
supplies raw camera frames (`MappingFrame`: a 1920 × 1440 `420f` image, a 256 × 192
`DepthFloat32` depth map, the camera transform and intrinsics, all from one frame), tracking
samples, and the reconstructed mesh at stop. A `.posedRGB` source returns `.posedRGB` from
`captureKind`, supplies `MappingRGBFrame` (a `420f` image at the size tracking started with, the
transform, the intrinsics and the frame's timestamp) from `acquireRGBFrame()`, and passes every
camera update to `MultiSet.shared.mapping.reportTrackingSample(_:)` with its tracking state,
feature-point count and light estimate. Pass every value raw; the SDK does every conversion. A
frame of any other size is dropped. Call `reportSourceFailure(_:)` when your session fails, and
`reportSourceInterrupted()` when it is interrupted. `MultiSetAR/Mapping/ARMappingSource.swift` is
the reference implementation.

### API

```swift
MultiSet.shared.mapping: MultiSetMapping
mapping.setSource(_ source: MultiSetMappingSource?)
mapping.scan: MappingScanState
mapping.beginPreview() async
mapping.endPreview()
mapping.startScan() async
mapping.stopScan() async -> MappingStopOutcome
mapping.cancelPackaging()
mapping.resumePackaging() async -> MappingStopOutcome
mapping.discardScan() async
mapping.acknowledgeFailure()
mapping.saveDraft(named: String) throws -> MappingDraft
mapping.reportSourceFailure(_ message: String)
mapping.reportSourceInterrupted() async
mapping.reportTrackingSample(_ sample: MappingTrackingSample)
mapping.drafts() -> [MappingDraft]
mapping.deleteDraft(id: String)
mapping.upload(draftID: String) async
mapping.uploadState(for draftID: String) -> MappingUploadState?
mapping.dismissUploadFailure(for draftID: String)
mapping.hasActiveUploads: Bool
mapping.resumeUploads() async
mapping.handleEventsForBackgroundURLSession(identifier: String, completionHandler: @escaping () -> Void)
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
