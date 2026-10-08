# Private simulator input troubleshooting

Read this when an available tool sends touches to the wrong Duo display or when maintaining a simulator input helper. This private simulator protocol was validated for display discovery, touch, fold, and orientation on Xcode 27.1 RC (27A9275) with the iOS 27.1 RC runtime (24A94232). It may change across versions and is neither an app-facing API nor a physical-device control path. On a headless simulator with those builds, legacy Indigo HID events sent to guessed or per-screen targets were reported to crash `backboardd`; avoid that path.

## Discover the active display and target

Run `xcrun simctl io <simulator-UDID> enumerate` after each boot. The `Connected Screens` entry's `Unique ID` is the display UUID, distinct from the simulator UDID and touch target. Determine the active display from its visible framebuffer and current `UI Orientation`; do not infer it from list order.

For a helper using CoreDevice's guest `dtuhidd` service, query `com.apple.coredevice.feature.remote.universalhidservice` with the discovery request `{isBarrier: false, payload: {connectedServices: {}}}`. Unlike an input event, this request has no `messageType` or `featureIdentifier`. Touchscreen records have `PrimaryUsagePage` `0x0d` and `PrimaryUsage` `0x04`. Match their `displayUUID` to the selected `simctl` Unique ID, then derive the digitizer target from `_ServiceID & 0xff`. On the validated runtime, cover, inner, and resizable displays had `_ServiceID` values `0x101`, `0x103`, and `0x105` (targets 1, 3, and 5). Discover the mapping each run rather than hardcoding those values.

## Guest service connection and message types

Use CoreSimulator's `-[SimDevice lookup:error:]` to look up the guest service Mach port. Handle a missing service or lookup error without sending input. Wrap the port with `xpc_endpoint_create_mach_port_4sim(port, 0, 0)`, create an XPC connection from the endpoint, and call `xpc_connection_enable_sim2host_4sim` before sending a message. The observed **event** envelope is `{messageType: string, isBarrier: bool, featureIdentifier: <service name>, payload: {...}}`. Encode integers as `uint64` and coordinates as `double`. An optional liveness check on the connected digitizer or vendor service is a barrier `IndigoKeyboardButtonEvent` with `{usageCode: 0, state: 2}` and the service as `featureIdentifier`; expect a reply before attempting input.

For digitizer input, use service `com.apple.coredevice.feature.remote.hid.digitizer`, message type `IndigoDigitizerEvent`, and payload `{pointOne: {x, y}, eventType, edge: 0, target}`. The observed `eventType` sequence is 0 for start, 1 for position, and 2 for end. Keep the connection open briefly after the end event so it drains and the touch reaches the app; 0.5 seconds was a validated starting allowance, not a guaranteed settling time. A successful send is insufficient evidence: check that the intended control visibly changes on the selected display.

Digitizer `x` and `y` are fractions of the **unrotated** panel. If starting from a point in the screenshot's current orientation, transform it into unrotated coordinates first, then divide by unrotated width `W` and height `H` in the same units. Do not transform a point that a helper already converted and normalized. Derive or validate the current point-to-pixel scale before converting screenshot coordinates; the observed inner panel was 2007 × 2853 pixels and 669 × 951 points on the validated runtime.

| `simctl` UI Orientation | Unrotated point from oriented `(x, y)` |
| --- | --- |
| Portrait | `(x, y)` |
| Landscape Left | `(y, H − x)` |
| Portrait Upside Down | `(W − x, H − y)` |
| Landscape Right | `(W − y, x)` |

Portrait and Landscape Left transforms were verified by visible touch effects on the inner display; a cover-display tap was also verified after closing the fold. Verify the other two transform rows on the target runtime before relying on them.

For orientation and fold control, use `com.apple.coredevice.feature.remote.hid.vendordefined`, message type `IndigoVendorDefinedEvent`, with `{usagePage: 0xff61, usage: 0x5b, version: 0, data}`. `data` is `IOCFSerialize(…, kIOCFSerializeToBinary)` of `{provider: "com.apple.Virtualization.VirtualMachines", source, type, value}`. Validated source/type pairs are `orientation-picker-control`/`enum` with values including `portrait` and `landscape-left`, and `hinge-slider-control`/`range` with a degree value from 0 to 180. On the validated runtime, body `portrait` produced inner `Landscape Left` UI, body `landscape-left` produced inner `Portrait`, and 0 degrees activated the cover display. Re-enumerate and verify the resulting display orientation, fold pose, and app layout after each change; an accepted event alone does not prove the requested angle, and this private event is not an official stability guarantee.
