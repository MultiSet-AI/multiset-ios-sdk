# MultiSet Swift SDK Samples

The sample app for the [MultiSet Swift SDK](https://github.com/MultiSet-AI/multiset-swift-package).
It shows localization, object tracking, map creation (LiDAR and Non-LiDAR), a GeoPose map view and
every SDK setting, and adds the SDK with Swift Package Manager.

To add the SDK to your own app, follow the
[package README](https://github.com/MultiSet-AI/multiset-swift-package#add-the-sdk-to-your-app).

## Requirements

- iOS 16.0+
- Xcode 26 or later
- A device with ARKit support (A12 chip or later). ARKit does not run in the simulator
- Map creation: any device above for a Non-LiDAR scan; a LiDAR scan also needs the LiDAR scanner
  (iPhone 12 Pro or a later Pro model, iPad Pro 2020 or later)

## Run the Sample App

1. Clone this repository and open `MultiSet-SDK-Samples.xcodeproj`:

   ```bash
   git clone https://github.com/MultiSet-AI/multiset-swift-samples.git
   ```

   Xcode fetches the SDK from
   [multiset-swift-package](https://github.com/MultiSet-AI/multiset-swift-package) at the version
   the project pins, and downloads its framework from that release.
2. Add your credentials and map code to `MultiSet-SDK-Samples/SDKConfig.swift`:

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
   [SERVER_AUTH_GUIDE.md](https://github.com/MultiSet-AI/multiset-swift-package/blob/main/SERVER_AUTH_GUIDE.md).
   Don't commit your credentials.

   To obtain credentials, visit [https://developer.multiset.ai/credentials](https://developer.multiset.ai/credentials).
3. Select your development team under **Signing & Capabilities**, then run on a device.

## What the Sample Shows

The gear icon on the landing screen edits the localization and object-tracking settings at runtime.
The **Mapping** card scans a space into a new map — on a LiDAR device choose **LiDAR** or
**Non-LiDAR**, on any other device it scans Non-LiDAR — and **Draft Maps** lists scans that have
not been uploaded yet.

On the AR screens, the small card at the top left shows each run's steps — capturing, uploading,
waiting on the server, then a tick or a red mark — and a bar at the bottom left shows a map or
object mesh while it loads. See
[Showing a Run's Progress](https://github.com/MultiSet-AI/multiset-swift-package#showing-a-runs-progress).

The **GeoPose Map View** card opens the AR view under a map that plots each localization's GeoPose
— the position and the way the camera faced — beside the device's GPS track. It works only with a
geo-referenced map or MapSet: other maps localize, but their responses carry no GeoPose to plot.
The map is Apple MapKit, so it needs no key, and it asks for location access to draw the GPS
track. See [Reading the GeoPose](https://github.com/MultiSet-AI/multiset-swift-package#reading-the-geopose).

## SDK Version

The project pins the SDK to an exact version, and this repository moves to each new SDK release.
To try another version, select the project in Xcode, open **Package Dependencies**, and change the
version of `multiset-swift-package`.

Versions up to 2.4.0 shipped from this repository, which was called `multiset-ios-sdk`, as a
committed `MultiSetSDK.xcframework` plus the `MultiSetAR` folder. From 2.5.0 the SDK ships only as
the Swift package; the
[package changelog](https://github.com/MultiSet-AI/multiset-swift-package/blob/main/CHANGELOG.md)
covers every release.

## License

Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License; see [LICENSE.md](LICENSE.md). For license details, visit [www.multiset.ai](https://www.multiset.ai).
