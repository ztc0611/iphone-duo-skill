# Private simulator input troubleshooting

Read this when the bundled `scripts/duo` helper sends touches to the wrong Duo display or when maintaining it. Its private simulator protocol was tested for display discovery, touch, drag, fold, and orientation on October 27, 2026 with Xcode 27.2 (27B48) and the iOS 27.2 Duo runtime (24B91016s). The protocol is neither an app-facing API nor a physical-device control path. On a headless 27.1 RC simulator, legacy Indigo HID events sent to guessed or per-screen targets were reported to crash `backboardd`; avoid that path rather than reproducing it.

## Discover the active display and target

Run `xcrun simctl io <simulator-UDID> enumerate` after each boot. The `Connected Screens` entry's `Unique ID` is the display UUID, distinct from the simulator UDID and touch target. Determine the active display from its visible framebuffer and current `UI Orientation`; do not infer it from list order.

The bundled helper queries CoreDevice's guest `dtuhidd` service, `com.apple.coredevice.feature.remote.universalhidservice`, with `{isBarrier: false, payload: {connectedServices: {}}}`. Unlike an input event, this request has no `messageType` or `featureIdentifier`. Touchscreen records have `PrimaryUsagePage` `0x0d` and `PrimaryUsage` `0x04`. Match their `displayUUID` to the selected `simctl` Unique ID, then derive the digitizer target from `_ServiceID & 0xff`. On 27.2, cover, inner, and resizable displays had `_ServiceID` values `0x101`, `0x103`, and `0x105` (targets 1, 3, and 5). Discover the mapping each run rather than hardcoding those values; display UUIDs changed after reboot.

## Guest service connection and message types

Use CoreSimulator's `-[SimDevice lookup:error:]` to look up the guest service Mach port. Handle a missing service or lookup error without sending input. Wrap the port with `xpc_endpoint_create_mach_port_4sim(port, 0, 0)`, create an XPC connection from the endpoint, and call `xpc_connection_enable_sim2host_4sim` before sending a message. The observed **event** envelope is `{messageType: string, isBarrier: bool, featureIdentifier: <service name>, payload: {...}}`. Encode integers as `uint64` and coordinates as `double`. An optional liveness check on the connected digitizer or vendor service is a barrier `IndigoKeyboardButtonEvent` with `{usageCode: 0, state: 2}` and the service as `featureIdentifier`; expect a reply before attempting input.

For digitizer input, use service `com.apple.coredevice.feature.remote.hid.digitizer`, message type `IndigoDigitizerEvent`, and payload `{pointOne: {x, y}, eventType, edge: 0, target}`. The observed `eventType` sequence is 0 for start, 1 for position, and 2 for end. Keep the connection open briefly after the end event so it drains and the touch reaches the app; 0.5 seconds was a validated starting allowance, not a guaranteed settling time. A successful send is insufficient evidence: check that the intended control visibly changes on the selected display.

Digitizer `x` and `y` are fractions of the **unrotated** panel. If starting from a point in the screenshot's current orientation, transform it into unrotated coordinates first, then divide by unrotated width `W` and height `H` in the same units. Do not transform a point that the bundled helper already converted and normalized. On 27.2, the inner panel was 2007 × 2853 pixels and 669 × 951 points, while the cover was 1398 × 2034 pixels and 466 × 678 points. Both used 3 pixels per point.

| `simctl` UI Orientation | Unrotated point from oriented `(x, y)` |
| --- | --- |
| Portrait | `(x, y)` |
| Landscape Left | `(y, H − x)` |
| Portrait Upside Down | `(W − x, H − y)` |
| Landscape Right | `(W − y, x)` |

All four transform rows were verified by visible taps on intended controls on the active inner display; a cover-display tap was also verified with the fold closed. A drag on the inner display reached a neutral pan gesture and moved it upward. Ordinary callers should use `scripts/duo` with displayed point coordinates rather than applying this table themselves.

For orientation and fold control, the bundled helper sends `com.apple.coredevice.feature.remote.hid.vendordefined`, message type `IndigoVendorDefinedEvent`, with `{usagePage: 0xff61, usage: 0x5b, version: 0, data}`. `data` is `IOCFSerialize(…, kIOCFSerializeToBinary)` of `{provider: "com.apple.Virtualization.VirtualMachines", source, type, value}`. Tested source/type pairs are `orientation-picker-control`/`enum` with values `portrait`, `pud`, `landscape-left`, and `landscape-right`, and `hinge-slider-control`/`range` with a degree value from 0 to 180. On 27.2, those body orientations produced inner UI `Landscape Left`, `Landscape Right`, `Portrait`, and `Portrait Upside Down`, respectively. A neutral app's `UIHingeInteraction` readback reported Closed at 0 radians, Partially Open near 1.53–1.62 radians for a 90-degree request, and Fully Open at π radians for 180 degrees. Re-enumerate and verify the resulting display orientation and app layout after each change; an accepted event alone does not prove the requested pose, and this private event is not an official stability guarantee.
