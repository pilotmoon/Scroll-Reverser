// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "MouseMonitor.h"
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDKeys.h>

NSString *const MouseMonitorKeyMouseConnected=@"mouseConnected";

@interface MouseMonitor ()
@property (getter=isMouseConnected) BOOL mouseConnected;
@property (assign) IOHIDManagerRef manager;
@property NSMutableSet<NSValue *> *mice;
- (void)deviceAdded:(IOHIDDeviceRef)device;
- (void)deviceRemoved:(IOHIDDeviceRef)device;
@end

static void deviceMatched(void *context, IOReturn result, void *sender, IOHIDDeviceRef device)
{
    [(__bridge MouseMonitor *)context deviceAdded:device];
}

static void deviceRemoved(void *context, IOReturn result, void *sender, IOHIDDeviceRef device)
{
    [(__bridge MouseMonitor *)context deviceRemoved:device];
}

// A trackpad reports itself as a mouse too, so tell them apart. The built-in trackpad is flagged
// as built in; external Magic Trackpads are recognised by name.
static BOOL isExternalMouse(IOHIDDeviceRef device)
{
    NSNumber *const builtIn=(__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDBuiltInKey));
    if (builtIn.boolValue) {
        return NO;
    }
    NSString *const product=(__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    if ([product rangeOfString:@"trackpad" options:NSCaseInsensitiveSearch].location!=NSNotFound) {
        return NO;
    }
    return YES;
}

@implementation MouseMonitor

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.mice=[NSMutableSet set];
        // Matching devices does not open them, so no extra permission is needed.
        self.manager=IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
        NSArray *const matching=@[
            @{@kIOHIDDeviceUsagePageKey: @(kHIDPage_GenericDesktop), @kIOHIDDeviceUsageKey: @(kHIDUsage_GD_Mouse)},
            @{@kIOHIDDeviceUsagePageKey: @(kHIDPage_GenericDesktop), @kIOHIDDeviceUsageKey: @(kHIDUsage_GD_Pointer)},
        ];
        IOHIDManagerSetDeviceMatchingMultiple(self.manager, (__bridge CFArrayRef)matching);
        IOHIDManagerRegisterDeviceMatchingCallback(self.manager, deviceMatched, (__bridge void *)self);
        IOHIDManagerRegisterDeviceRemovalCallback(self.manager, deviceRemoved, (__bridge void *)self);
        IOHIDManagerScheduleWithRunLoop(self.manager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        // pick up mice that are already connected now, so mouseConnected is correct from the start
        NSSet *const devices=(__bridge_transfer NSSet *)IOHIDManagerCopyDevices(self.manager);
        for (id device in devices) {
            [self deviceAdded:(__bridge IOHIDDeviceRef)device];
        }
    }
    return self;
}

- (void)dealloc
{
    if (self.manager) {
        IOHIDManagerUnscheduleFromRunLoop(self.manager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        CFRelease(self.manager);
    }
}

- (void)deviceAdded:(IOHIDDeviceRef)device
{
    if (!isExternalMouse(device)) {
        return;
    }
    NSValue *const key=[NSValue valueWithPointer:device];
    if ([self.mice containsObject:key]) {
        return;
    }
    [self.mice addObject:key];
    [self update];
}

- (void)deviceRemoved:(IOHIDDeviceRef)device
{
    NSValue *const key=[NSValue valueWithPointer:device];
    if (![self.mice containsObject:key]) {
        return;
    }
    [self.mice removeObject:key];
    [self update];
}

- (void)update
{
    const BOOL connected=self.mice.count>0;
    if (connected!=self.mouseConnected) {
        self.mouseConnected=connected;
    }
}

@end
