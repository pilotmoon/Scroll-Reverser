// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Foundation/Foundation.h>
#import "IOKitSPI.h"

NS_ASSUME_NONNULL_BEGIN

// What a scroll event tells us about where it came from, from most to least specific.
typedef NS_ENUM(NSInteger, ScrollSourceKind) {
    ScrollSourceKindLocalDevice=0,      // HID event from a service in the IORegistry
    ScrollSourceKindRemoteDevice,       // HID event from a virtual service, such as Universal Control's
    ScrollSourceKindUnidentifiedDevice, // HID event, but the sender is 0 or can't be found
    ScrollSourceKindApp,                // no HID event, posted by another process (pid != 0)
    ScrollSourceKindUnidentified,       // no HID event and pid 0 (Sidecar, in practice)
};

// The broad type of a source, for display and defaults. Trackpads are identified by their scroll
// acceleration type or driver; any other device is a mouse.
typedef NS_ENUM(NSInteger, ScrollSourceCategory) {
    ScrollSourceCategoryTrackpad=0,
    ScrollSourceCategoryMouse,
    ScrollSourceCategoryOther,
};

// A source of scroll events, which gets its own row of settings.
@interface ScrollSource : NSObject

// Stable identifier for the source's row. Built from device properties, a bundle ID or an
// executable path, never from a sender ID or pid.
@property (readonly) NSString *key;
@property (readonly) ScrollSourceKind kind;
@property (readonly) ScrollSourceCategory category;
// Name reported by the device or app, if any.
@property (readonly, nullable) NSString *name;
// Bundle or executable path, for app sources.
@property (readonly, nullable) NSString *path;
// Sources that don't identify a device have separate rows for continuous and
// non-continuous scrolling.
@property (readonly) BOOL splitByContinuity;
@property (readonly) BOOL continuous; // only meaningful if splitByContinuity

/* Key building, separated from the lookups so it can be tested. `properties` holds the sending
 service's HID properties (kIOHIDProductKey and so on). `trackpadDriver` is whether the service is
 driven by the multitouch trackpad driver. */
+ (ScrollSource *)deviceSourceWithKind:(ScrollSourceKind)kind properties:(NSDictionary<NSString *, id> *)properties trackpadDriver:(BOOL)trackpadDriver;
// The non-continuous and continuous sources for an app, identified by bundle ID or executable path.
+ (NSArray<ScrollSource *> *)appSourcesWithIdentifier:(NSString *)identifier name:(nullable NSString *)name path:(NSString *)path;

@end

/* Maps scroll events to sources. Lookups happen only the first time a HID sender or pid is
 seen, so it is cheap to call for every event. Main thread only. */
@interface ScrollSourceIdentifier : NSObject

- (ScrollSource *)sourceForHIDEvent:(nullable IOHIDEventRef)hidEvent pid:(pid_t)pid continuous:(BOOL)continuous;

@end

NS_ASSUME_NONNULL_END
