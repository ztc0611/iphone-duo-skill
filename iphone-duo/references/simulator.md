# Driving an iPhone Duo simulator

Use a simulator that the user has authorized for this work. Check the project's device reservations before selecting one. Do not boot, shut down, install to, or change an unrelated simulator or a physical device. Validated with Xcode 27.1 RC (27A9275) and iOS 27.1 RC (24A94232). Recheck runtime-dependent behavior after upgrades and keep local observations distinct from Apple's documentation.

## Fold and orientation control

Device Hub provides a visible hinge slider and orientation picker. Use a specific authorized simulator, and record its initial pose when it can be read. For headless automation, use a project-integrated, verified display-aware simulator tool if one is available. The [private simulator input reference](simulator-input.md) describes the observed `dtuhidd` protocol for maintaining such a helper; this skill does not bundle one. Do not assume a successful control command changed the fold or orientation.

```bash
xcrun simctl list devices booted
SIMULATOR_ID="<authorized booted foldable simulator UDID>"
```

Simulator fold controls use degrees: 0 is closed, 180 is flat, and an intermediate value such as 90 requests a partial pose. UIKit's `UIHinge.angle` is in **radians**; SwiftUI's hinge angle is an `Angle`. Convert units when comparing them.

After changing the fold or orientation, allow about a second for the UI to settle, then inspect the active display and app state. Check the reported angle when a reliable readback is available; if it fails or returns no angle, report the uncertainty rather than assuming the requested pose took effect. Restore the initial pose when appropriate. No fixed delay guarantees that layout and animations have settled.

## Screenshots and recordings

The Duo has separate cover and inner content displays. Re-enumerate after each simulator boot. In `Connected Screens`, identify the intended screen by its name and pixel size, then copy that screen's **Unique ID** (a screen UUID). This differs from `SIMULATOR_ID`, which identifies the simulator itself, and from a touch target. Do not infer a display from enumeration order or hardcode a numeric screen ID. On this runtime, `primary` was the 1398 × 2034 cover panel and `primary-1` was the 2007 × 2853 inner panel; these are examples, not selection constants. Enumeration lists native unrotated panel dimensions, while a screenshot follows the screen's current `UI Orientation` and may have different width and height.

```bash
xcrun simctl io "$SIMULATOR_ID" enumerate
DISPLAY_UUID="<Unique ID of the selected Connected Screens entry>"
xcrun simctl io "$SIMULATOR_ID" screenshot --display="$DISPLAY_UUID" out.png
```

To inspect a pose transition frame by frame, record the same discovered display:

```bash
xcrun simctl io "$SIMULATOR_ID" recordVideo --codec=h264 --display="$DISPLAY_UUID" out.mp4
```

Stop recording with Control-C or SIGINT and wait for `simctl` to finalize the file. Bound capture startup and finalization in automation; an invalid display selector can hang. Give automated screenshot subprocesses a short timeout or runner deadline. A black capture can mean the selected display is inactive, the simulator is recovering from a `backboardd` crash, or a startup capture issue. Apple lists issue 187146039 for black Duo captures and recordings for a few minutes after boot in [Xcode 27.2 beta 2 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes); that note does not establish the issue in Xcode 27.1. Inspect the selected display, fold state, and simulator health, then recapture rather than treating a black image or PNG byte count as proof of a pose.

## Touch input and orientation

Test the active, lit display; a black inactive framebuffer cannot demonstrate a touch effect. A successful input command does not prove which display received it. In the reported RC setup, the legacy main digitizer target `50` reached the cover even while the inner display was active. Guessed or per-screen legacy Indigo HID targets could crash `backboardd` on a headless simulator. Do not probe those targets; if input repeatedly fails or the screen goes black after a crash, stop and recover only the authorized simulator. Check the available project's tool help and display support, then verify that a tap causes the intended visible change on the selected display. If no verified display-aware driver is available, use Device Hub's input or orientation controls where available, or report the input limitation.

When an available tool misroutes touches, or when maintaining a simulator input helper, read [private simulator input troubleshooting](simulator-input.md) for the observed display-aware `dtuhidd` path. Its protocol is private and version-specific; ordinary app tests need only verify the intended visible effect.

On this runtime, the orientation picker interpreted body `portrait` as an open inner display in `Landscape Left` (wide), and body `landscape-left` as inner `Portrait` (upright). The app must support the requested interface orientation for its layout to follow. Verify the target screen's reported `UI Orientation` and app layout after using the picker; a control command's exit status is insufficient. Allow about a second for the state to settle, then inspect it.

For PiP setup and layout checks, read [Picture in Picture testing](picture-in-picture.md).

## Limits

The `dtuhidd` control path is private simulator tooling, separate from app-facing APIs and physical-device controls. Recheck its behavior after Xcode or runtime upgrades.

In Xcode 27.1 beta, initial Simulator launch may take several minutes, StandBy is unavailable in the Duo simulator, and most app extensions cannot run or be debugged there. [Apple: Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)
