// Drives a booted simulator's displays the way Device Hub does, through the
// guest's CoreDevice HID daemon (dtuhidd), so touches can land on the iPhone
// Duo's inner display and its orientation and hinge can be set from the CLI.
// The wire format follows facebook/idb's FBSimulatorControl (MIT): services
// are looked up in the simulator's bootstrap namespace and reached through
// the private xpc *_4sim endpoint calls.
//
//   duohid <udid> displays
//   duohid <udid> tap <target> <x> <y>
//   duohid <udid> drag <target> <x1> <y1> <x2> <y2> <seconds>
//   duohid <udid> orient <portrait|pud|landscape-left|landscape-right>
//   duohid <udid> hinge <degrees>
//
// Coordinates are unit coordinates (0 to 1) of the target display; `target`
// comes from `displays`.
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFSerialize.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <xpc/xpc.h>

static NSString *const DigitizerService = @"com.apple.coredevice.feature.remote.hid.digitizer";
static NSString *const VendorService = @"com.apple.coredevice.feature.remote.hid.vendordefined";
static NSString *const UniversalService = @"com.apple.coredevice.feature.remote.universalhidservice";

static id device;

static xpc_connection_t connect(NSString *service) {
    typedef xpc_object_t (*EndpointFromPort)(mach_port_t, uint64_t, uint64_t);
    typedef void (*EnableSim2Host)(xpc_connection_t);
    EndpointFromPort endpointFromPort = (EndpointFromPort)dlsym(RTLD_DEFAULT, "xpc_endpoint_create_mach_port_4sim");
    EnableSim2Host enableSim2Host = (EnableSim2Host)dlsym(RTLD_DEFAULT, "xpc_connection_enable_sim2host_4sim");
    if (!endpointFromPort || !enableSim2Host) { fprintf(stderr, "xpc _4sim symbols unavailable\n"); exit(1); }
    NSError *error;
    mach_port_t port = ((mach_port_t (*)(id, SEL, id, NSError **))objc_msgSend)(
        device, NSSelectorFromString(@"lookup:error:"), service, &error);
    if (port == MACH_PORT_NULL) { fprintf(stderr, "lookup %s: %s\n", service.UTF8String, error.description.UTF8String); exit(1); }
    xpc_object_t endpoint = endpointFromPort(port, 0, 0);
    xpc_connection_t connection = xpc_connection_create_from_endpoint((xpc_endpoint_t)endpoint);
    enableSim2Host(connection);
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {});
    xpc_connection_resume(connection);
    return connection;
}

static xpc_object_t envelope(NSString *type, NSString *service, BOOL barrier, xpc_object_t payload) {
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "messageType", type.UTF8String);
    xpc_dictionary_set_bool(message, "isBarrier", barrier);
    xpc_dictionary_set_string(message, "featureIdentifier", service.UTF8String);
    xpc_dictionary_set_value(message, "payload", payload);
    return message;
}

// A barrier with usage 0, "no event", answered by a live daemon without the
// guest seeing a key.
static void confirmLive(xpc_connection_t connection, NSString *service) {
    xpc_object_t payload = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_uint64(payload, "usageCode", 0);
    xpc_dictionary_set_uint64(payload, "state", 2);
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(
        connection, envelope(@"IndigoKeyboardButtonEvent", service, YES, payload));
    if (xpc_get_type(reply) == XPC_TYPE_ERROR) {
        fprintf(stderr, "%s did not answer: %s\n", service.UTF8String,
                xpc_dictionary_get_string(reply, XPC_ERROR_KEY_DESCRIPTION));
        exit(1);
    }
    usleep(200000);
}

static void drain(xpc_connection_t connection) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    xpc_connection_send_barrier(connection, ^{ dispatch_semaphore_signal(done); });
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    usleep(120000);
}

static void sendTouch(xpc_connection_t connection, uint64_t target, double x, double y, uint64_t phase) {
    xpc_object_t point = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_double(point, "x", x);
    xpc_dictionary_set_double(point, "y", y);
    xpc_object_t payload = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_value(payload, "pointOne", point);
    xpc_dictionary_set_uint64(payload, "eventType", phase); // 0 start, 1 position, 2 end
    xpc_dictionary_set_uint64(payload, "edge", 0);
    xpc_dictionary_set_uint64(payload, "target", target);
    xpc_connection_send_message(connection, envelope(@"IndigoDigitizerEvent", DigitizerService, NO, payload));
}

static void sendVendor(NSString *source, NSString *type, id value) {
    NSDictionary *report = @{
        @"provider": @"com.apple.Virtualization.VirtualMachines",
        @"source": source, @"type": type, @"value": value,
    };
    CFDataRef data = IOCFSerialize((__bridge CFTypeRef)report, kIOCFSerializeToBinary);
    if (!data) { fprintf(stderr, "could not serialize the report\n"); exit(1); }
    xpc_object_t payload = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_uint64(payload, "usagePage", 0xff61);
    xpc_dictionary_set_uint64(payload, "usage", 0x5b);
    xpc_dictionary_set_uint64(payload, "version", 0);
    xpc_dictionary_set_data(payload, "data", CFDataGetBytePtr(data), CFDataGetLength(data));
    CFRelease(data);
    xpc_connection_t connection = connect(VendorService);
    confirmLive(connection, VendorService);
    xpc_connection_send_message(connection, envelope(@"IndigoVendorDefinedEvent", VendorService, NO, payload));
    drain(connection);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 3) {
            fprintf(stderr, "usage: duohid <udid> displays | tap <target> x y | drag <target> x1 y1 x2 y2 s | "
                            "orient <portrait|pud|landscape-left|landscape-right> | hinge <degrees>\n");
            return 2;
        }
        NSString *udid = @(argv[1]);
        NSString *command = @(argv[2]);
        if (!dlopen("/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator", RTLD_NOW)) {
            fprintf(stderr, "dlopen CoreSimulator: %s\n", dlerror());
            return 1;
        }
        NSError *error;
        const char *selectedDeveloperDir = getenv("DEVELOPER_DIR");
        NSString *developerDir = selectedDeveloperDir && selectedDeveloperDir[0]
            ? [NSString stringWithUTF8String:selectedDeveloperDir]
            : @"/Applications/Xcode.app/Contents/Developer";
        id context = ((id (*)(id, SEL, id, NSError **))objc_msgSend)(
            NSClassFromString(@"SimServiceContext"), NSSelectorFromString(@"sharedServiceContextForDeveloperDir:error:"),
            developerDir, &error);
        id deviceSet = ((id (*)(id, SEL, NSError **))objc_msgSend)(
            context, NSSelectorFromString(@"defaultDeviceSetWithError:"), &error);
        for (id candidate in [deviceSet valueForKey:@"devices"]) {
            if ([[[candidate valueForKey:@"UDID"] UUIDString] isEqualToString:udid]) device = candidate;
        }
        if (!device) { fprintf(stderr, "no simulator %s\n", udid.UTF8String); return 1; }

        if ([command isEqualToString:@"displays"]) {
            xpc_connection_t connection = connect(UniversalService);
            xpc_object_t payload = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_value(payload, "connectedServices", xpc_dictionary_create(NULL, NULL, 0));
            xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_bool(request, "isBarrier", false);
            xpc_dictionary_set_value(request, "payload", payload);
            xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, request);
            char *description = xpc_copy_description(reply);
            if (argc > 3) { printf("%s\n", description); }
            free(description);
            // Touchscreens: digitizer page 0x0D, usage 0x04, service ID 0x100 | target.
            __block void (^walk)(xpc_object_t) = nil;
            void (^visit)(xpc_object_t) = ^(xpc_object_t object) {
                if (xpc_get_type(object) == XPC_TYPE_DICTIONARY) {
                    uint64_t page = xpc_dictionary_get_uint64(object, "PrimaryUsagePage");
                    uint64_t usage = xpc_dictionary_get_uint64(object, "PrimaryUsage");
                    if (page == 0x0D && usage == 0x04) {
                        uint64_t serviceID = xpc_dictionary_get_uint64(object, "_ServiceID");
                        const char *display = xpc_dictionary_get_string(object, "displayUUID");
                        printf("target %llu  display %s  (service 0x%llx)\n", serviceID & 0xFF,
                               display ?: "(none)", serviceID);
                    }
                    xpc_dictionary_apply(object, ^bool(const char *key, xpc_object_t value) { walk(value); return true; });
                } else if (xpc_get_type(object) == XPC_TYPE_ARRAY) {
                    xpc_array_apply(object, ^bool(size_t index, xpc_object_t value) { walk(value); return true; });
                }
            };
            walk = visit;
            walk(reply);
        } else if ([command isEqualToString:@"tap"] && argc >= 6) {
            uint64_t target = strtoull(argv[3], NULL, 0);
            double x = atof(argv[4]), y = atof(argv[5]);
            xpc_connection_t connection = connect(DigitizerService);
            confirmLive(connection, DigitizerService);
            sendTouch(connection, target, x, y, 0);
            drain(connection);
            usleep(100000);
            sendTouch(connection, target, x, y, 2);
            drain(connection);
            // Closing the connection resets the daemon's gesture state, so
            // the touch is given time to reach the app first.
            usleep(500000);
        } else if ([command isEqualToString:@"drag"] && argc >= 9) {
            uint64_t target = strtoull(argv[3], NULL, 0);
            double x1 = atof(argv[4]), y1 = atof(argv[5]), x2 = atof(argv[6]), y2 = atof(argv[7]);
            double seconds = atof(argv[8]);
            int steps = MAX(2, (int)(seconds * 60));
            xpc_connection_t connection = connect(DigitizerService);
            confirmLive(connection, DigitizerService);
            sendTouch(connection, target, x1, y1, 0);
            for (int i = 1; i <= steps; i++) {
                double t = (double)i / steps;
                sendTouch(connection, target, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, 1);
                usleep((useconds_t)(seconds * 1e6 / steps));
            }
            sendTouch(connection, target, x2, y2, 2);
            drain(connection);
            usleep(500000);
        } else if ([command isEqualToString:@"orient"] && argc >= 4) {
            sendVendor(@"orientation-picker-control", @"enum", @(argv[3]));
        } else if ([command isEqualToString:@"hinge"] && argc >= 4) {
            sendVendor(@"hinge-slider-control", @"range", @(atof(argv[3])));
        } else {
            fprintf(stderr, "unknown command\n");
            return 2;
        }
    }
    return 0;
}
