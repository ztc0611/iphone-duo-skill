---
name: iphone-duo
description: Build and review adaptive iPhone Duo interfaces, or test app behavior across its displays and fold states in the Xcode simulator. Use for hinge APIs, reserved regions, arrangement views, multiple scenes, and simulator fold testing.
---

# iPhone Duo

Use this skill for iPhone Duo app work and simulator checks. Its API baseline is the Xcode 27.1 beta with the iOS 27.1 SDK and runtime. Apple's Duo guidance is preliminary and may change; confirm exact symbols and behavior against the SDK in use before relying on them. Keep Apple's published guidance distinct from simulator observations and third-party tooling.

When available, Apple's App Resizability skill (exported from Xcode with `xcrun agent skills export`) complements the Duo-specific layout and testing guidance here with scene lifecycle, window-relative traits, and changing safe areas. [Apple: skill export](https://developer.apple.com/videos/play/wwdc2026/278/) · [Apple: Duo preparation](https://developer.apple.com/videos/play/tech-talks/111461/)

Read [app development](references/app-development.md) when writing or reviewing app code, layouts, toolbars, hinge effects, or scenes. Read [simulator testing](references/simulator.md) when selecting a simulator, controlling its fold, routing touch input, changing orientation, taking screenshots, or checking device behavior. Read [Picture in Picture testing](references/picture-in-picture.md) when testing PiP layout or simulator setup. Use both development and testing guidance when a task spans implementation and verification.

## Core layout rules

- Adapt to the current window scene's size classes, safe areas, and geometry. Duo's cover and inner displays commonly have different size classes, and multiple windows can differ at the same time. Treat the published size-class table as a starting point, not a substitute for current traits.
- Let system navigation and toolbar containers adapt to the available edges. Avoid hardcoded positions, symmetric safe-area assumptions, and layout decisions based on device model or interface orientation alone.
- Use reserved regions and arrangement views to keep content clear of the fold and occlusions. Use hinge status or angle for interaction effects, not as the primary layout mechanism.
- Do not hardcode either display's pixel dimensions. Simulator-reported dimensions may differ from published hardware specifications.
- When code needs a screen, use its window scene's screen. Get scale from the relevant trait collection when only scale is needed.

## Verification

Exercise each view, sheet, popover, and toolbar on the cover and inner displays. Check closed, partially open, and fully open poses; rotate where supported and check transitions between poses. Test multiple windows and Split View when the app supports them. Test the app beneath another app's pinned PiP in flat and partial poses, then unpin and verify its layout restores. Inspect controls near the fold or camera region, vertical system bars, and asymmetric safe areas. With the same window configuration, test Dynamic Type, right-to-left layout, an interactive back gesture, and repeated flat–partial–flat and sidebar cycles. Confirm frames actually change and restore, while content, selection, and logical scroll position persist. On each display, verify that a tap produces its intended visible state change; a tool's successful exit does not prove the touch reached that display. Re-enumerate display identifiers after reboot. Xcode 27.1 Previews can show the other display through the Display group in canvas overrides; use it for quick iteration, then confirm in the simulator. Record the Xcode/runtime version and whether each finding comes from Apple documentation, direct observation, or another source.
