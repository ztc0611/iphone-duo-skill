# Picture in Picture testing on iPhone Duo

Use this guide to test how an app behaves beneath another app's pinned Picture in Picture (PiP) video. Apple describes video pinning above the current app and a partial-fold presentation that can give video half the display. Check layout using the current window scene's geometry and safe areas, then confirm content, selection, and logical scroll position survive pinning, pose changes, and returning to the unpinned layout. Cover-screen landscape is a different window configuration and does not replace testing the actual app beneath pinned PiP. [Apple: Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/) · [Apple: multiple displays and scenes](https://developer.apple.com/videos/play/tech-talks/111464/)

## Simulator setup

The [Duo PiP Test fixture](https://github.com/ztc0611/duo-piptest) is a small AVKit video player with five aspect ratios and a setup helper. The workflow was validated from fixture commit `20ec0e7` with Xcode 27.1 RC (27A9275) and iOS 27.1 RC (24A94232). On that runtime, the installed Duo profile had `PiPOverlay` and `PiPPinned` disabled. The helper copies the profile into a local ignored directory, enables only those flags in the copy, and selects it when the named simulator boots. This is experimental simulator configuration, not an app API or shipping entitlement. It does not edit Apple's installed profile.

Choose a dedicated, authorized iPhone Duo by exact simulator UUID. Confirm its type and reservation before any restart, and keep it in the closed cover pose for the override boot. From the fixture checkout, with `SIMULATOR_ID` set to that UUID, run:

```bash
./scripts/build.sh
python3 scripts/run.py --device "$SIMULATOR_ID" --restart
python3 scripts/run.py --device "$SIMULATOR_ID" --status
```

The explicit `--restart` shuts down only that simulator and closes its running apps. The helper then boots with the local copied profile, installs and launches the video source, and checks the effective capability path. Require `PiP override active: yes` from `--status` before testing. Keep the fixture checkout and its ignored `.runtime/` copy in place until that simulator shuts down. After a later reboot, recheck the override; an ordinary boot may return to stock capabilities. Do not edit Apple's profile or restart an unrelated simulator.

## Test the layout

Identify the actual app under test by its bundle ID. The video fixture is only the PiP source; pinning over itself does not test the other app's layout. Use this order:

1. In the video source, choose an aspect ratio and tap **Start Picture in Picture** (`startPiPButton`). Confirm a floating video appears. If it does not, inspect the app's readiness state and PiP delegate callback.
2. Make the inner display active in UI `Portrait` (body `landscape-left`; see [fold and orientation control](simulator.md)). Only then open or foreground the **actual app under test** by its known bundle ID and confirm it is visible beneath the floating video. The fixture is not the underlay target. Safari (`com.apple.mobilesafari`) is a fallback for checking the automation itself; use the task's real app for design review.
3. Tap the floating video to reveal its native controls. On the tested iOS 27.1 RC inner-Portrait layout, the **left** vertically stacked-rectangles control in the top-right pill pins or unpins video; the **right** overlapping-windows control restores fullscreen and ends PiP. Use the current accessibility label when available; otherwise locate the control visually. Controls can auto-hide, so reveal and tap promptly; a bounded reveal-then-tap sequence may be needed. For automated touches, target the active inner display using [display-aware input and orientation conversion](simulator-input.md). Do not hardcode a screen ID, target, or coordinate.
4. Verify pinning by the visible video region above the app and the app's reduced-height layout, not by a touch command's exit status. Check that the app's toolbar and content adapt within the reduced area. Fold partially and inspect how both regions change. Return flat, reveal the controls, and use the same **left** control to unpin; verify floating video and the app's full-height layout return.

Test a wide source (16:9 or 21:9) and a taller source (4:3 or 1:1), plus a partial-fold pose. Taller video can consume more height while flat; partial fold can give the video about half the display with letterboxing and less space for the app below. The observed 4:3 and 1:1 presentations left similar app height, but no ratio is a fixed layout threshold. Measure the app's current window geometry and safe areas instead of inferring its size from the video ratio.

For a player app, also verify that its own PiP start, stop, and failure states reflect `AVPictureInPictureController` results; see [AVKit's custom-player guide](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player).
