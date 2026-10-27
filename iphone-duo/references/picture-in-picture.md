# Picture in Picture testing on iPhone Duo

Use this guide to test how an app behaves beneath another app's pinned Picture in Picture (PiP) video. Apple describes video pinning above the current app and a partial-fold presentation that can give video half the display. Check layout using the current window scene's geometry and safe areas, then confirm content, selection, and logical scroll position survive pinning, pose changes, and returning to the unpinned layout. Cover-screen landscape is a different window configuration and does not replace testing the actual app beneath pinned PiP. [Apple: Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/) · [Apple: multiple displays and scenes](https://developer.apple.com/videos/play/tech-talks/111464/)

## Simulator setup

The [Duo PiP Test fixture](https://github.com/ztc0611/duo-piptest) is a small AVKit video player with five aspect ratios and a setup helper. On October 27, 2026, the installed Duo device profile still had `PiPOverlay` and `PiPPinned` disabled with Xcode 27.2 (27B48) and the iOS 27.2 Duo runtime (24B91016s). A copied-profile capability override enabled native PiP using fixture commit `1b0c15e` (clean checkout) built with the iOS 27.2 SDK.

This is experimental simulator configuration, not an app API or shipping entitlement; never edit Apple's installed profile. Choose a dedicated, authorized Duo by exact simulator UUID. Confirm its type and reservation, close it to the cover pose, and shut down only that simulator before the override boot. The copied fixture helper can create a local ignored `.runtime/<UDID>/capabilities.plist` from the installed Duo profile with only the two PiP flags enabled. The override must be passed into the simulator's **boot**, using the boot wrapper required by the environment. On the tested machine that wrapper was `simslim on`:

```bash
SIMULATOR_ID="<authorized Duo simulator UDID>"
DUO_PROFILE="/Library/Developer/CoreSimulator/Profiles/DeviceTypes/iPhone Duo.simdevicetype/Contents/Resources/capabilities.plist"
PIP_CAPABILITIES="$PWD/.runtime/$SIMULATOR_ID/capabilities.plist"
mkdir -p "$(dirname "$PIP_CAPABILITIES")"
cp "$DUO_PROFILE" "$PIP_CAPABILITIES"
plutil -replace capabilities.PiPOverlay -bool YES "$PIP_CAPABILITIES"
plutil -replace capabilities.PiPPinned -bool YES "$PIP_CAPABILITIES"
# With only this authorized Duo shut down, use the required boot wrapper.
SIMCTL_CHILD_SIMULATOR_CAPABILITIES="$PIP_CAPABILITIES" \
  simslim on "$SIMULATOR_ID" --profile "<boot-profile>"
xcrun simctl getenv "$SIMULATOR_ID" SIMULATOR_CAPABILITIES
```

Require the effective path to equal `PIP_CAPABILITIES` and the copied flags to be true before expecting native PiP. If the environment uses another boot wrapper, pass `SIMCTL_CHILD_SIMULATOR_CAPABILITIES` to that wrapper. From the fixture checkout, after the matching override is active:

```bash
./scripts/build.sh
python3 scripts/run.py --device "$SIMULATOR_ID" --app build/DuoPiPTest.app
python3 scripts/run.py --device "$SIMULATOR_ID" --status
```

The tested fixture helper path kept the already booted simulator running, checked the effective profile, then installed and launched the video source without `--restart`. Require `PiP override active: yes` from `--status`. Keep the fixture checkout and its ignored `.runtime/` copy in place until that simulator shuts down. After any later reboot, recheck the effective override; an ordinary boot can return to stock capabilities. Do not restart an unrelated simulator.

## Test the layout

Identify the actual app under test by its bundle ID. The video fixture is only the PiP source; pinning over itself does not test the other app's layout. Use this order:

1. In the video source, choose an aspect ratio and tap **Start Picture in Picture** (`startPiPButton`). Confirm a floating video appears. If it does not, inspect the app's readiness state and PiP delegate callback.
2. Make the inner display active in UI `Portrait` and verify its reported orientation (see [fold and orientation control](simulator.md)). Foreground the **actual app under test** by its known bundle ID and confirm it is visible beneath the floating video. The fixture is only the PiP source.
3. Tap the floating video to reveal its native controls. On the tested 27.2 inner-Portrait layout, the **left** vertically stacked-rectangles control pinned video and the **right** overlapping-windows control restored fullscreen. Controls auto-hide, so reveal and tap promptly; a bounded reveal-then-tap sequence may be needed. For automated touches, target the active inner display using [display-aware input and orientation conversion](simulator-input.md). Discover its screen UUID and touch target each boot rather than hardcoding them.
4. Verify pinning by the video region above the app and the app's reduced-height layout. With a 16:9 source and a neutral underlay on the tested 27.2 runtime, the underlay's window was 669 × 951 points unpinned, 669 × 564.67 points pinned flat, and 669 × 465.33 points pinned around 90 degrees. The pin control also unpinned at both fold poses, restoring the full 669 × 951-point window. Measure the actual app's geometry and safe areas instead of treating those sample heights as layout constants.

For an app's layout review, test the video shapes it must support and a partial-fold pose. A taller video can consume more height while flat; partial fold can give video about half the display with letterboxing. Measure the current window geometry and safe areas instead of inferring them from the video's ratio.

For a player app, also verify that its own PiP start, stop, and failure states reflect `AVPictureInPictureController` results; see [AVKit's custom-player guide](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player).
