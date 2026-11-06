# Changelog

## 2.2.0

Requires iOS 16.0+ and Xcode 26 or later. Replace `MultiSetSDK.xcframework`; the `MultiSetAR/`
folder is unchanged from 2.1.0. No breaking API changes.

### New

- **Token provider:** `MultiSetConfig(credentials: .tokenProvider(_:), ...)` takes access tokens
  from your own server, so the client secret never ships in the app. Implement
  `MultiSetTokenProvider` or wrap a closure in `ClosureTokenProvider`; the SDK asks with a reason
  (`.initial`, `.expiring`, `.rejected`). See "Keeping the Client Secret on Your Server" in the
  README and [SERVER_AUTH_GUIDE.md](SERVER_AUTH_GUIDE.md).
- `MultiSetCredentials` and `MultiSetConfig.credentials`. The existing `clientId:clientSecret:`
  initializers and factories are unchanged.
- **Demo app:** `SDKConfig.tokenServerURL` and `TokenServerProvider` try the flow against your own
  endpoint.

### Fixed

- `onAuthenticationFailure(error:)` always received "Ready to authenticate". It now receives the
  actual reason, such as `Authentication failed: HTTP 401 ...`.
- A request refused with a 401 within 10 s of a new token was resent with that same token, a
  certain second 401 that re-uploaded every frame of a multi-frame query. It is no longer resent
  with a token the API has already refused.

## 2.1.0

Requires iOS 16.0+ and Xcode 26 or later. Replace `MultiSetSDK.xcframework` and the `MultiSetAR/`
folder together. No breaking API changes; all new callbacks are optional.

### New

- **Map creation** with `MultiSet.shared.mapping`: scan a space with LiDAR (`.lidar`) or on any
  ARKit device (`.posedRGB`), keep it as a draft, and upload it to be built into a map. Needs
  `MultiSetAR/Mapping/` and two app delegate hooks; see "Map Creation" in the README.
- **Run progress:** `onLocalizationStageChanged(_:isBackground:)` and
  `onObjectTrackingStageChanged(_:isBackground:)` report each run as capturing, uploading, waiting
  on the server, or idle (`LocalizationStage`).
- **Mesh loading:** `MultiSet.shared.isMapMeshLoading` and `isObjectMeshLoading`.
- **Recovery state:** `onRecoveryPhaseChanged(_:needsRealignment:)`. Hide content placed in the map
  frame while `needsRealignment` is true.
- **VPS-2 in multi-frame mode:** `queryMode` now applies to multi-frame localization too.
- **Demo app:** map creation screens, plus the MultiSet app's capture overlays, run status card and
  mesh loading bar. Stop stays disabled until a scan reaches 10 s, and an alert warns one minute
  before the 10-minute limit.

### Changed

- `relocalization` now re-localizes automatically after a tracking break, hiding the map mesh until
  it succeeds. In 2.0 the flag had no effect.
- `firstLocalizationUntilSuccess` and `firstObjectTrackingUntilSuccess` retry at most 5 times before
  reporting a failure. In 2.0 they retried indefinitely.
- `MultiSetARView` starts a new world frame when the app returns from the background. If you use
  your own `ARView`, see "Using Your Own ARView" in the README.
- `initialize(config:callback:)` accepts credentials without a map or object code; `localize()` and
  `startObjectTracking()` report the missing code instead.
- `bgLocalizationDurationSeconds` accepts 10–180 s (was 15–180).
- The framework's privacy manifest declares disk-space access (`E174.1`).

### Fixed

- Map mesh and object outlines were misaligned after returning from the background in a different
  place.
- Object tracking failed with "No frame captured" after returning from the background.

## 2.0.0 (build 2)

A rebuild of `MultiSetSDK.xcframework` with two MapSet mesh fixes. No API change, and the
`MultiSetAR/` folder and demo app are identical to build 1 — if you are not using a MapSet,
replacing the framework is optional.

### Fixed

- **A MapSet's details were re-requested on every successful localization.**
  `/v1/vps/map-set/{code}` is now fetched once and reused, so background localization no longer
  costs an extra round trip per fix.
- **A map's mesh could be placed at another map's offset.** The offset was read from state the
  mesh handler held across its three requests — MapSet detail, signed URL, download — so when
  `updateConfig` retargeted between a single map and a MapSet while a mesh was still
  downloading, whichever load finished last decided where the earlier one's mesh went. The
  offset is now resolved per load and passed down with it.

## 2.0.0

Requires iOS 16.0+ and Xcode 26 or later. Device only — ARKit does not run in the simulator.

A major release. The ARKit and RealityKit code has moved out of the binary framework and now
ships as source you compile into your app, the false-positive filter has been rebuilt, and a
plan-driven watermark has been added.

### Breaking changes

**1. The SDK is now a framework plus a source folder.** `MultiSetSDK.xcframework` no longer
contains any ARKit, RealityKit, SwiftUI or CoreLocation code. Everything AR-facing —
`MultiSetARView`, mesh rendering, the Metal shaders, GPS hints — ships as readable source in
`MultiSetAR/` (14 files), which you add to your app target.

The API is unchanged. `MultiSetARView()`, `setARSession`, `setParentEntity`,
`setObjectTrackingRootEntity` and `setGizmoVisible` all still exist; they now come from the
folder instead of the binary. Two things to watch:

- Module-qualified references such as `MultiSetSDK.MultiSetARView` no longer compile.
- Mixing a 1.16.0 xcframework with the new folder makes `MultiSetARView` ambiguous. Replace both
  together.

If you set `passGeoPose = true` without using `MultiSetARView`, call
`MultiSet.shared.setGeoHintProvider(CoreLocationGeoHintProvider())` after `initialize`.

**2. `MultiSet` and `MultiSetCallback` are `@MainActor`.** Calling `MultiSet.shared` from a
synchronous non-main context no longer compiles — wrap it in `DispatchQueue.main.async { }` or
`Task { @MainActor in }`. A class adopting `MultiSetCallback` is inferred `@MainActor`, so
create it on the main thread.

**3. `GeoCoordinates.altitude` is now `Double?`** and is height above the WGS84 ellipsoid. It is
`nil` when the server sent no height; 1.16.0 reported `0`.

**4. `poseConsistencyCheck` now defaults to `false`.** In 1.16.0 the false-positive gate was on by
default. This is a silent change — nothing fails to compile — so if you relied on it, set it
explicitly.

**5. `poseConsistencyThreshold` changed meaning and range.** It is now a flat distance limit in
metres, range 1–15, default 4. In 1.16.0 it was a ceiling on a tolerance that widened with time. A
1.16.0 value above 15 is clamped.

**6. `GateTuning` lost six fields.** `rejectionBaseM`, `rejectionMaxM`, `driftRateMPerSec`,
`rejectionBaseDeg`, `rejectionMaxDeg` and `driftRateDegPerSec` are replaced by
`rejectionDistanceM` and `rejectionYawDeg`. Code that set any of the six no longer compiles.

### New

**Rebuilt false-positive filter.** The pose consistency check is now a vote across separated
query viewpoints rather than a single distance threshold, and it can correct a wrong anchor by
itself rather than only rejecting.

- `poseConsistencyYawThreshold` — heading limit in degrees, 5–60, default 25. Independent of the
  distance limit: a response can sit well inside the distance and still be refused on heading,
  which is the signature of an identical-corridor match. Both limits are applied flat and
  reported verbatim in `FalsePositiveInfo`.
- `MultiSet.shared.anchorTrust` (`.provisional` / `.corroborated` / `.trusted`) with
  `onAnchorTrustChanged(_:)`.
- `onLocalizationCorrected(from:to:trust:)` fires when the anchor moves under content you have
  already placed.
- `FalsePositiveInfo` gained `thresholdDegrees`, `yawDeltaDeg`, `disagreement`, `cause`,
  `challengerSupport`, `requiredSupport`, `incumbentSupport` and `trust`.
- `poseConsistencyTuning: GateTuning?` and `mapAliasingRisk` for spaces with repeated structure.

**`MultiSet.shared.resetSession()`.** Stops localization and tracking, removes every mesh, drops
the gate's reference and restarts the frame source's world origin. This is the exit from a bad
*first* fix — that fix bootstraps the anchor unchecked and, from a MultiFrame request, as
`.trusted`, after which every correct response is the one reported as a false positive. Offer it
from your false-positive UI, not just a toolbar. Credentials and authentication survive; call
`localize()` when ready.

**Custom AR runtimes.** Four protocols let you drive the SDK from something other than ARKit:
`MultiSetFrameSource`, `MultiSetPoseSink`, `MultiSetMeshRenderer` and `MultiSetGeoHintProvider`,
with `CameraFrame`, `AnchorPose`, `MapMeshAsset` and `ObjectMeshAsset`. Tracking is reported
through `notifyTrackingInterrupted()`, `notifyWorldOriginReset()` and `reportTrackingState(_:)`.

**Object tracking state.** `isObjectTrackingActive` turns on the moment a capture is requested;
`isShowingObjectTrackingOverlay` excludes background re-tracking. Drive a capture button from
the first and a progress indicator from the second.

### Changed behaviour

- Every callback now arrives on the main thread. In 1.16.0 `onLocalizationFailure` could arrive on
  a background thread.
- After a failed request, background localization retries after `bgLocalizationDurationSeconds`.
  In 1.16.0 that retry was scheduled off the main run loop and never fired.
- `stopLocalization()` and `stopObjectTracking()` now also cancel a pending retry or delayed
  capture. In 1.16.0 an already-scheduled retry could start a new request after the stop.
- `geoHint` altitude is now ellipsoidal (1.16.0 sent mean-sea-level). A fix without valid altitude
  sends `latitude,longitude` only and forces `use2DFiltering` for that request.
- The location permission prompt appears when `MultiSetARView` is created or a geo-hint provider
  is attached, not at sign-in.
- `onTrackingStateChanged` no longer fires a synthetic `.paused` on view creation, and is
  delivered synchronously.
- The built-in gizmo moves before `onLocalizationSuccess`, not after. `setGizmoUpdateHandler` no
  longer disconnects `MultiSetARView`'s own gizmo.
- The object-tracking outline now matches the MultiSet app: a thin animated purple outline
  instead of a glowing shell, on iOS 16 and 17 as well.
- Meshes no longer freeze the AR view while loading, and two objects whose meshes arrive
  together both render; in 1.16.0 the second could be dropped.
- With `passGeoPose = true` and no geo-hint provider attached, no `geoHint` is sent and the SDK
  logs a warning once.
- With no mesh renderer attached, meshes are not downloaded and `onObjectMeshLoaded` does not
  fire.
- The radial reveal centres on the camera position when the mesh arrives, not when its download
  started.
- Unchanged on purpose: `onMeshLoaded` still fires after every accepted fix, whether or not a
  mesh was drawn.

### Fixed

- **Object tracking could crash the app after leaving the tracking screen.** Stopping tracking
  cancelled the in-flight request, which was reported as a failure; the resulting alert was
  presented on a view controller already detached from the hierarchy, corrupting the
  presentation and taking down the next AR view. Cancellation is no longer reported as a
  failure.
- **Object meshes did not reload after leaving and re-entering the tracking screen.**
- **Background re-tracking retried at 1 second instead of `bgObjectTrackingDurationSeconds`**,
  because the background flag was cleared immediately after being set.

### Upgrade checklist

1. Replace `MultiSetSDK.xcframework` and add the `MultiSetAR/` folder to your app target. Both
   `.metal` files must be in **Compile Sources**, not Copy Bundle Resources.
2. Remove any module-qualified `MultiSetSDK.MultiSetARView` references.
3. Unwrap `GeoCoordinates.altitude`.
4. Set `poseConsistencyCheck = true` if you relied on it, and re-tune `poseConsistencyThreshold`
   for its new 1–15 flat meaning.
5. Replace any `GateTuning` field from the removed six.
6. Lift bottom-left controls by `watermarkClearance`.
