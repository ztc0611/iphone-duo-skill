# App development

This reference uses the Xcode 27.1 beta with the iOS 27.1 SDK as its API baseline. Apple's Duo material is preliminary; check the installed SDK when exact spellings or availability matter. Links labeled **Apple** cite first-party material. Simulator measurements belong in [simulator testing](simulator.md), where they can be tied to a specific runtime.

## Displays and adaptive layout

Apple lists a 5.4-inch, 1398 × 2034-pixel cover display and a 7.6-inch, 1878 × 2670-pixel inner display with nano-texture. These are hardware specifications, not layout constants. Use the window's current traits, geometry, and safe area instead of fixed pixel or point sizes. [Apple specifications](https://www.apple.com/iphone-duo/specs/)

Apple's default size-class examples are:

| Display | Orientation | Horizontal | Vertical |
| --- | --- | --- | --- |
| Cover | Portrait | Compact | Regular |
| Cover | Landscape | Compact | Compact |
| Inner | Either | Regular | Regular |

Use the actual scene's traits, especially when the app has multiple windows. The inner display generally does not follow an app's orientation restrictions; an app that restricts its supported orientations may be scaled on the inner display, including in Split View. `UIRequiresFullScreen` remains honored, but the app still resizes as Duo opens and closes. Do not use interface orientation or `UIDevice.current.userInterfaceIdiom` as a stand-in for available layout space. [Apple: Prepare your app](https://developer.apple.com/videos/play/tech-talks/111461/)

The **SDK used to build the binary**, rather than its deployment target or the simulator runtime alone, determines which Duo layout behavior it adopts. Running an older build on an iOS 27.1 simulator does not grant it the iOS 27.1 layout. [Apple: Prepare your app](https://developer.apple.com/videos/play/tech-talks/111461/)

| Build SDK | Duo layout behavior |
| --- | --- |
| iOS 26 or earlier | The app still runs. On the cover it uses the area left of the status bar and camera; on the inner display it receives a familiar-size, familiar-aspect compatibility layout. |
| iOS 27.0 | The app extends left of the status-bar area on the inner display and uses the iOS 27 resizing foundation. |
| iOS 27.1 (Xcode 27.1) | The app reaches the inner screen edge. Standard navigation and toolbar buttons can arrange vertically under the status bar where the container supports it. |

Prefer the latest supported SDK and system navigation/toolbar containers, then verify both displays. [Apple: Prepare your app](https://developer.apple.com/videos/play/tech-talks/111461/)

In the Xcode 27.1 beta, iOS 27.1-only APIs, including the hinge, reserved-region, and arrangement APIs, fail to compile for Mac Catalyst, and projects targeting iOS 27.1 show no Mac Catalyst run destination. If the app ships a Catalyst target, guard that code with `#if !targetEnvironment(macCatalyst)` and add a Mac Catalyst 27.0 minimum deployment. [Apple: Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)

## Fold and reserved regions

Use hinge information for interaction effects, such as changing a gesture or animation as the device moves. Use layout information to place content. Prefer hinge status for discrete behavior; angle updates are not guaranteed at a fixed rate or granularity. [Apple: Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/) · [Apple: hinge angle](https://developer.apple.com/documentation/uikit/uihinge/angle)

- UIKit: `UIHingeInteraction(updateHandler:)` supplies an update whose `hinge` is optional. It can be `nil` after the interaction leaves the view hierarchy; do not interpret it solely as proof of a device without a hinge. `UIHinge.status` has `unknown`, `closed`, `partiallyOpen`, and `fullyOpen`; its `angle` is a `CGFloat` in **radians**. [Apple: UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction)
- SwiftUI: `onHingeChange(isEnabled:_:)` receives old and new `DeviceHingeContext` values. Read the optional `context.hinge` before using its status or `Angle` value. `DeviceHinge.Status` provides `closed`, `partiallyOpen`, and `fullyOpen` values, with no `unknown` value; allow a fallback when switching over statuses. Do not assume the context itself has `status` or `angle` members. [Apple: Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/)
- For layout, inspect `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)` or `UIView.reservedRegions(kind:options:)`. The `.division` kind describes the fold; `.occlusion` covers obstructions such as a camera. Frames are local to the queried view and already include the region's `margins`, which pad it for interactive content. SwiftUI's default layout-direction behavior mirrors them for right-to-left layout. [Apple: Strike a pose](https://developer.apple.com/videos/play/tech-talks/111463/) · [Apple: reservedRegions](https://developer.apple.com/documentation/swiftui/geometryproxy/reservedregions%28kind%3Aoptions%3Alayoutdirectionbehavior%3A%29)

Apple's beta references differ on whether inactive regions are returned by default. For avoiding obstructions, filter queried regions by `isActive`; when deliberately inspecting inactive geometry, request `options: .includeInactive` and still inspect the flag. The division region is inactive and zero width when flat. The inner camera's occlusion is active only while the camera is active. [Apple: Strike a pose](https://developer.apple.com/videos/play/tech-talks/111463/) · [Apple: UIView.ReservedRegion](https://developer.apple.com/documentation/uikit/uiview/reservedregion)

`ArrangementView { primary } secondary: { secondary }` and `UIArrangementViewController` place related content across or over the fold; SwiftUI styles include `.split` and `.overlay`. Keep navigation containers such as `NavigationSplitView` outside `ArrangementView`; avoid placing `ArrangementView` inside `List` or `ScrollView`. [Apple: Strike a pose](https://developer.apple.com/videos/play/tech-talks/111463/)

For articles, feeds, and lists, preserve continuous scrolling instead of shifting the entire scrolling surface away from the fold. [Apple: Strike a pose](https://developer.apple.com/videos/play/tech-talks/111463/)

## Custom layout checks

Implementation checks, not Apple API guarantees or a reason to replace `ArrangementView`:

- **Coordinate spaces:** When a pane uses a different coordinate space, convert reserved-region rectangles into that space before intersection or insetting. Account for safe-area origin, pane offset, and layout direction. During an interactive back gesture, ensure stationary fold/camera regions don't move with pushed content. If the gesture makes content reflow, consider measuring from a stable ancestor and translating into the pane.
- **Custom columns:** Intersect the active division region with usable safe-area bounds, then measure each side independently. A sidebar or edge bar may make the sides asymmetric. Require readable width at the current Dynamic Type size; a regular horizontal size class alone does not establish that two columns fit.
- **Scroll insets:** Identify which layer owns each inset: container, section, or scroll adjustment. Check that horizontal safe area is not applied twice. Avoid disabling all automatic adjustments as a general fix, because vertical refresh behavior can depend on them.
- **Identity and reflow:** Keep persistent pane and content identity across display changes. Invalidate width-dependent text and row measurements when usable width changes. Preserve logical selection and scroll anchor across widths instead of restoring a raw scroll offset.

## Bars, scenes, and cameras

System bars can move to a vertical edge. A standalone custom `UINavigationBar`, `UIToolbar`, or `UITabBar` does not gain that placement automatically. Keep primary navigation and action containers in consistent locations; standard icon-and-title toolbar items adapt to the available axis, while text-only items stay horizontal. In iOS 27.1, SwiftUI's `toolbarVerticalEdge` reports the preferred vertical edge, not a guarantee that a vertical bar is visible; a container such as a sheet or split-view detail may have different placement. Use `ToolbarContent.axisBehavior(.verticalPreferred)` when a custom view has a usable vertical form, not as a blanket setting for standard items; use `.horizontalOnly` for a custom item that switches between a symbol and text. The vertical bar follows the hardware and stays on the same physical side in right-to-left languages, so read `toolbarVerticalEdge` instead of deriving its side from layout direction. Compute available bounds with the actual left and right safe-area insets, since they need not match. [Apple: toolbar adaptation](https://developer.apple.com/videos/play/tech-talks/111462/) · [Apple: toolbarVerticalEdge](https://developer.apple.com/documentation/swiftui/environmentvalues/toolbarverticaledge) · [Apple: axisBehavior](https://developer.apple.com/documentation/swiftui/toolbarcontent/axisbehavior%28_%3A%29)

For a layout better served by horizontal controls, such as a bottom-heavy single-page interface or a sheet with only a close button, apply `.toolbarVerticalBehavior(.disabled)` in SwiftUI, or override `UIViewController.preferredVerticalBarBehavior` to return `.disabled` in UIKit, to opt out of vertical bar placement. Eligible toolbar content then stays in its horizontal bar; the modifier does not hide the bar. Make this a considered layout choice rather than toggling it for fleeting state changes. If the goal is to hide a bar, use toolbar visibility controls instead. [Apple: toolbarVerticalBehavior](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior%28_%3A%29) · [Apple: when to opt out](https://developer.apple.com/videos/play/tech-talks/111462/)

Toolbar content can be conditionally shown in layouts where the bar is presented vertically. In cramped cover landscape, give icon actions meaningful titles, prioritize essential actions with `visibilityPriority(_:)`, and consider `ToolbarOverflowMenu` for less important actions. [Apple: toolbar adaptation](https://developer.apple.com/videos/play/tech-talks/111462/)

Duo supports multiple scenes per app. New app windows can open on the inner display only. `UIWindowSceneActivationAction` hides when a new window is unavailable; direct scene requests can fail, so handle their result. [Apple: Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/)

Use a window scene's screen rather than `UIScreen.main`, which Apple says is ambiguous on a two-display device and will be deprecated. [Apple: Prepare your app](https://developer.apple.com/videos/play/tech-talks/111461/) When only scale is needed, use `traitCollection.displayScale`.

The cover-display camera accessory is a specific camera capture flow while the app is full screen on the inner display and its camera is active. Do not treat it as a general-purpose second-display surface. [Apple: CameraCaptureAccessory](https://developer.apple.com/documentation/swiftui/cameracaptureaccessory)
