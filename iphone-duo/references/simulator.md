# Driving an iPhone Duo simulator

Use Xcode 27.2 with an iOS 27.2 Duo simulator runtime. Use a simulator that the user has authorized for this work. Check the project's device reservations before selecting one. Do not boot, shut down, install to, or change an unrelated simulator or a physical device. The concrete behavior below was tested on October 27, 2026 with Xcode 27.2 (27B48) and the iOS 27.2 Duo runtime (24B91016s). [Apple: Xcode 27.2 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes)

## Fold and orientation control

Device Hub provides pose buttons, an Option-drag hinge slider, and orientation controls. The bundled `scripts/duo` helper can also fold, rotate, tap, drag, and capture the Duo headlessly. Its first use builds and caches the native `duohid` backend from the included source, so Xcode command-line tools must be available. Use a specific authorized simulator, record its initial pose when possible, and verify control commands by reading display state or observing the app. The [private input reference](simulator-input.md) is for troubleshooting the bundled helper. [Apple: Device Hub controls](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub#Interact-with-your-iOS-app-on-an-iPhone-Duo-simulator)

```bash
xcrun simctl list devices booted
SIMULATOR_ID="<authorized booted foldable simulator UDID>"
```

Set `DUO_CLI` to this skill's bundled wrapper. These are helper commands, not `simctl` subcommands. The interface and visible effects were tested on 27.2:

```bash
DUO_CLI="<path-to-this-skill>/scripts/duo"
"$DUO_CLI" "$SIMULATOR_ID" displays
"$DUO_CLI" "$SIMULATOR_ID" hinge 180
"$DUO_CLI" "$SIMULATOR_ID" orient wide
"$DUO_CLI" "$SIMULATOR_ID" orient upright
"$DUO_CLI" "$SIMULATOR_ID" tap inner 100 100
"$DUO_CLI" "$SIMULATOR_ID" drag inner 100 150 100 80 0.4
"$DUO_CLI" "$SIMULATOR_ID" shot inner out.png
```

`tap` and `drag` take `inner` or `cover` and coordinates in the currently displayed screen's points. On this runtime, `orient wide` produced inner UI `Landscape Left`; `orient upright` produced inner UI `Portrait`. Only the lit display accepts touches. If the helper cannot run, use Device Hub's controls or report the failure rather than improvising private HID messages.

Simulator fold controls use degrees: 0 is closed, 180 is flat, and an intermediate value such as 90 requests a partial pose. On 27.2, a UIKit `UIHingeInteraction` readback after these helper commands reported Closed at 0 radians, Partially Open near 1.53–1.62 radians for a 90-degree request, and Fully Open at π radians. UIKit's `UIHinge.angle` is in **radians**; SwiftUI's hinge angle is an `Angle`. The partial angle is approximate because update granularity is system policy.

After changing the fold or orientation, allow the UI to settle, then inspect the active display and app state. Read the hinge status or angle when the test depends on the pose; a successful command alone does not establish the resulting layout. Restore the initial pose when appropriate. No fixed delay guarantees that animations have settled.

## Screenshots and recordings

The Duo has separate cover and inner content displays. Re-enumerate after each simulator boot; display UUIDs changed across a 27.2 reboot. In `Connected Screens`, identify the intended screen by its name and pixel size, then copy that screen's **Unique ID** (a screen UUID). This differs from `SIMULATOR_ID`, which identifies the simulator itself, and from a touch target. Do not infer a display from enumeration order or hardcode a numeric screen ID. On the tested runtime, `primary` was the 1398 × 2034 cover panel (466 × 678 points) and `primary-1` was the 2007 × 2853 inner panel (669 × 951 points); both used 3 pixels per point. Enumeration lists native unrotated dimensions, while a screenshot follows the current `UI Orientation` and may have different width and height.

```bash
xcrun simctl io "$SIMULATOR_ID" enumerate
DISPLAY_UUID="<Unique ID of the selected Connected Screens entry>"
xcrun simctl io "$SIMULATOR_ID" screenshot --display="$DISPLAY_UUID" out.png
```

To inspect a pose transition frame by frame, record the same discovered display:

```bash
xcrun simctl io "$SIMULATOR_ID" recordVideo --codec=h264 --display="$DISPLAY_UUID" out.mp4
```

Stop recording with Control-C or SIGINT and wait for `simctl` to finalize the file. A 27.2 selected-display H.264 recording finalized with moving video frames. Bound capture startup and finalization in automation; an invalid display selector failed in testing, and stale UUIDs must be refreshed after boot. Give automated screenshot subprocesses a short timeout or runner deadline. If a capture is black, check whether that display is inactive and inspect the fold state and simulator health before recapturing. A PNG byte count alone does not prove a pose.

## Touch input and orientation

Test the active, lit display; a black inactive framebuffer cannot demonstrate a touch effect. A successful input command does not prove which display received it. In historical 27.1 RC testing, the legacy main digitizer target `50` reached the cover even while the inner display was active, and guessed or per-screen legacy Indigo HID targets could crash `backboardd` headlessly. Do not probe those legacy targets. The bundled display-aware helper reached the intended inner and closed-cover controls on 27.2; verify the intended app effect for each test.

If the helper misroutes touches or needs maintenance, read [private simulator input troubleshooting](simulator-input.md) for its display-aware `dtuhidd` path. Its protocol is private; ordinary app tests need only verify the intended visible effect.

On the tested 27.2 runtime, body `portrait` produced inner UI `Landscape Left` (wide), `pud` produced `Landscape Right`, `landscape-left` produced `Portrait` (upright), and `landscape-right` produced `Portrait Upside Down`. All four display-aware touch transforms reached intended controls in a neutral app. The app must support the requested interface orientation for its layout to follow. Inspect the reported `UI Orientation` and app layout after changing it; a control command's exit status is insufficient.

For PiP setup and layout checks, read [Picture in Picture testing](picture-in-picture.md).

## Limits

The `dtuhidd` control path is private simulator tooling, separate from app-facing APIs and physical-device controls. Revalidate it after Xcode or runtime upgrades or if the bundled helper fails.
