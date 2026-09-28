# Driving an iPhone Duo simulator

Use a simulator that the user has authorized for this work. Check the project's device reservations before selecting one. Do not boot, shut down, install to, or change an unrelated simulator or a physical device.

## Hinge CLI

[Hinge](https://github.com/artemnovichkov/hinge) controls the fold angle of a **booted foldable iOS Simulator**. Its documented baseline is Xcode 27.1 or later with a foldable simulator runtime. These commands were checked against [Hinge 0.1.0 at commit `7acb090` (2026-09-26)](https://github.com/artemnovichkov/hinge/tree/7acb090dd7d28fb0aea8e1907211ceff15aa450e), including its [CLI source](https://github.com/artemnovichkov/hinge/blob/7acb090dd7d28fb0aea8e1907211ceff15aa450e/skills/hinge/scripts/hinge) and [bundled skill](https://github.com/artemnovichkov/hinge/blob/7acb090dd7d28fb0aea8e1907211ceff15aa450e/skills/hinge/SKILL.md). Check current help before relying on this version's details.

In Xcode 27.1 beta 1, built-in command-line tools do not expose simulator hinge control. Agents need Hinge or a similar helper for CLI control; users can control the hinge directly in Device Hub.

Before installing Hinge or any prerequisite, ask the user for permission and wait for an affirmative answer. Do not install automatically. If a usable Hinge installation or documented project integration already exists, use it without reinstalling. Once authorized, install the standalone command with:

```bash
brew install artemnovichkov/tap/hinge
command -v hinge
hinge --version
hinge help
```

Reading this guide does not require installation. The first angle change compiles and caches a small simulator helper using Xcode's clang. `hinge get` reads through `devicectl` and does not compile the helper.

Always target a specific authorized simulator. Hinge's default `booted` selector picks the **first** booted simulator, which may be unrelated to the test.

```bash
xcrun simctl list devices booted
SIMULATOR_ID="<authorized booted foldable simulator UDID>"

hinge -d "$SIMULATOR_ID" get
hinge -d "$SIMULATOR_ID" 120
hinge -d "$SIMULATOR_ID" set 120
hinge -d "$SIMULATOR_ID" open              # 180 degrees, flat
hinge -d "$SIMULATOR_ID" close             # 0 degrees, closed
hinge -d "$SIMULATOR_ID" half              # 90 degrees
hinge -d "$SIMULATOR_ID" sweep 180 0 2     # animate over 2 seconds
```

Hinge's CLI takes **degrees** from 0 to 180. UIKit's `UIHinge.angle` is in **radians**; SwiftUI's hinge angle is an `Angle`. Convert units when comparing app values with CLI output.

Read the initial angle before a test and restore it afterward when appropriate. After an angle change, allow the UI to settle and verify the result with `hinge -d "$SIMULATOR_ID" get` and the app's observed state. A successful helper exit alone does not establish that the fold changed. `get` may take a few seconds or fail to return an angle; report that uncertainty instead of assuming the requested pose took effect. A short wait, such as half a second, is a starting point, not a guarantee that layout and animations have settled.

## Screenshots

The Duo has separate cover and inner content displays. In the `Connected Screens` section of `enumerate`, identify the intended screen by its name and pixel size, then copy that screen's **Unique ID** (a screen UUID). This differs from `SIMULATOR_ID`, which identifies the simulator itself. Do not infer a display from enumeration order or hardcode a numeric screen ID. Width and height can swap when the screen rotates.

```bash
xcrun simctl io "$SIMULATOR_ID" enumerate
DISPLAY_UUID="<Unique ID of the selected Connected Screens entry>"
xcrun simctl io "$SIMULATOR_ID" screenshot --display="$DISPLAY_UUID" out.png
```

Give automated screenshot subprocesses a short timeout or runner deadline: an invalid display selector can hang. An inactive inner display can produce a black screenshot while folded. Inspect the selected display and fold state rather than treating a black image or a PNG byte count as proof of a specific pose.

## Limits

Hinge is simulator-only. It sends a private, undocumented event, so behavior can change with Xcode or runtime updates. Device Hub's visible slider may not track changes made by the CLI. Recheck the angle and app behavior after upgrades. Hinge does not provide a physical-device fold control.

In Xcode 27.1 beta, initial Simulator launch may take several minutes, StandBy is unavailable in the Duo simulator, and most app extensions cannot run or be debugged there. [Apple: Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)
