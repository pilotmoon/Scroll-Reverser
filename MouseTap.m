// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "MouseTap.h"
#import "CoreFoundation/CoreFoundation.h"
#import "TapLogger.h"
#import "AppDelegate.h"
#import <mach/mach_time.h>

static BOOL _preventReverseOtherApp;

static NSString *const kKeyActive=@"active";

#define MILLISECOND ((uint64_t)1000000)

static ScrollPhase _momentumPhaseForEvent(CGEventRef event)
{
    switch ([[NSEvent eventWithCGEvent:event] momentumPhase]) {
        case NSTouchPhaseBegan:
            return ScrollPhaseStart;
        case NSTouchPhaseStationary:
            return ScrollPhaseMomentum;
        case NSTouchPhaseEnded:
        case NSTouchPhaseCancelled:
            return ScrollPhaseEnd;
        default:
            return ScrollPhaseNormal;
    }
}

static uint64_t _nanoseconds(void)
{
    static mach_timebase_info_data_t info={0};
    if (info.denom==0) {
        mach_timebase_info(&info);
    }

    // convert to nanoseconds
    uint64_t time = mach_absolute_time();
    time *= info.numer;
    time /= info.denom;

    return * (uint64_t *) &time;
}

static NSInteger _stepsize(void)
{
    const NSInteger setting=[[NSUserDefaults standardUserDefaults] integerForKey:PrefsDiscreteScrollStepSize];
    if (setting<0) return 0;
    if (setting>100) return 100;
    return setting;
}

static CGEventRef _callback(CGEventTapProxy proxy,
                           CGEventType type,
                           CGEventRef eventRef,
                           void *userInfo)
{
    @autoreleasepool
    {
        MouseTap *const tap=(__bridge MouseTap *)userInfo;
        const uint64_t time=_nanoseconds();
        NSEvent *const event=[NSEvent eventWithCGEvent:eventRef];
        [(AppDelegate *)[NSApp delegate] refreshPermissions];

        if (type==(CGEventType)NSEventTypeGesture)
        {
            const NSUInteger touching=[[event touchesMatchingPhase:NSTouchPhaseTouching inView:nil] count];
        
            if (touching>=2) {
                [tap->logger logUnsignedInteger:touching forKey:@"touching"];
                tap->lastTouchTime=time;
                tap->touching=MAX(tap->touching, touching);
            }
            else {
                return eventRef; // totally ignore zero or one touch events
            }
        }
        else if (type==(CGEventType)NSEventTypeScrollWheel)
        {
            IOHIDEventRef const ioHidEventRef=CGEventCopyIOHIDEvent(eventRef);

            // is inverted from device? (1=natural scrolling, 0=classic scrolling)
            const BOOL invertedFromDevice=!![event isDirectionInvertedFromDevice];
            [tap->logger logBool:invertedFromDevice forKey:@"ifd"];

            // is continuous (magic mouse and magic trackpad scrolling is continuous)
            const BOOL continuous=!!CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventIsContinuous);
            [tap->logger logBool:continuous forKey:@"continuous"];

            // get the scrolling deltas
            const int64_t axis1=CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis1); // non-const since we may modify
            const int64_t axis2=CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis2);
            const int64_t point_axis1=CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis1);
            const int64_t point_axis2=CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis2);
            const double fixedpt_axis1=CGEventGetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis1);
            const double fixedpt_axis2=CGEventGetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis2);
            IOHIDFloat iohid_axis1=0;
            IOHIDFloat iohid_axis2=0;
            if (ioHidEventRef) {
                iohid_axis1=IOHIDEventGetFloatValue(ioHidEventRef, kIOHIDEventFieldScrollY);
                iohid_axis2=IOHIDEventGetFloatValue(ioHidEventRef, kIOHIDEventFieldScrollX);
            }
            [tap->logger logSignedInteger:axis1 forKey:@"y"];
            [tap->logger logSignedInteger:axis2 forKey:@"x"];
            [tap->logger logSignedInteger:point_axis1 forKey:@"y_pt"];
            [tap->logger logSignedInteger:point_axis2 forKey:@"x_pt"];
            [tap->logger logDouble:fixedpt_axis1 forKey:@"y_fp"];
            [tap->logger logDouble:fixedpt_axis2 forKey:@"x_fp"];
            [tap->logger logDouble:iohid_axis1 forKey:@"y_iohid"];
            [tap->logger logDouble:iohid_axis2 forKey:@"x_iohid"];
         
            // get source pid
            const uint64_t pid=CGEventGetIntegerValueField(eventRef, kCGEventSourceUnixProcessID);
            [tap->logger logUnsignedInteger:pid forKey:@"pid"];
            
            // calculate elapsed time since touch
            const uint64_t touchElapsed=(time-tap->lastTouchTime);
            [tap->logger logNanoseconds:touchElapsed forKey:@"elapsed"];
            
            // get and reset fingers touching
            const NSUInteger touching=tap->touching;
            [tap->logger logUnsignedInteger:touching forKey:@"touching"];
            tap->touching=0;

            // get phase
            const ScrollPhase phase=_momentumPhaseForEvent(eventRef);
            [tap->logger logPhase:phase forKey:@"phase"];
            
            // work out the event source
            const ScrollEventSource lastSource=tap->lastSource;
            const ScrollEventSource source=(^{
                switch (event.subtype) {
                    case NSEventSubtypeMouseEvent:
                        [tap->logger logBool:YES forKey:@"subtypeMouse"];
                        return ScrollEventSourceMouse;
                    case NSEventSubtypeTabletPoint:
                        [tap->logger logBool:YES forKey:@"subtypeTabletPoint"];
                        return ScrollEventSourceTrackpad;
                    default:
                        [tap->logger logBool:YES forKey:@"subtypeOther"];
                        return ScrollEventSourceMouse;
                }
            })();
            tap->lastSource=source;
            
            // finally, do we reverse the scroll or not?
            const BOOL invert=(^BOOL {
                
                /* Don't reverse scrolling coming from another app (if that setting is on).
                 This is useful if Scroll Reverser is running inside a remote desktop, to ignore
                 scrolling coming from the controlling host but still reverse local scrolling.
                 */
                const BOOL preventBecauseComingFromOtherApp=_preventReverseOtherApp?pid!=0:NO;
                
                if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling]&&!preventBecauseComingFromOtherApp)
                {
                    switch (source)
                    {
                        case ScrollEventSourceTrackpad:
                            return [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseTrackpad];
                            
                        case ScrollEventSourceMouse:
                        default:
                            return [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseMouse];
                    }
                }
                else {
                    return NO;
                }
            })();
            
            [tap->logger logBool:invert forKey:@"reversing"];
            [tap->logger logSource:source forKey:@"source"];

            if(source!=lastSource) {
                [tap->logger logMessage:@"Source changed" special:YES];
            }
            
            // show discrete scroll prefs if we have seen non-continuous scrolling
            // (only do this once)
            if (!continuous) {
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    [(AppDelegate *)[NSApp delegate] enableDiscreteScrollOptions];
                });
            }

            // Adjust discrete scroll wheel?
            const NSInteger stepsize=_stepsize();
            const BOOL discreteAdjust=stepsize>0&&llabs(axis1)==1&&!continuous;
            const NSInteger vstep=discreteAdjust?stepsize:1;
            [tap->logger logSignedInteger:vstep forKey:@"vstep"];

            // Calculate signed multiplier to apply
            const NSInteger vmul=(invert&&[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseVertical])?-vstep:vstep;
            const NSInteger hmul=(invert&&[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseHorizontal])?-1:1;

            /* Do the actual reversing. It's worth noting we have to set the point values second, or we lose smooth scrolling.
             This is because setting DeltaAxis causes macos to internally modify PointDeltaAxis (8x multiplier on DeltaAxis
             value) and FixedPtDeltaAxis (1x multiplier). */
            if (discreteAdjust||vmul!=1) { // vertical
                CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis1, axis1*vmul);
            }
            if (!discreteAdjust&&vmul!=1) { // vertical - only set these if not doing discrete adjust
                CGEventSetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis1, fixedpt_axis1*vmul);
                CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis1, point_axis1*vmul);
                if (ioHidEventRef) {
                    IOHIDEventSetFloatValue(ioHidEventRef, kIOHIDEventFieldScrollY, iohid_axis1*vmul);
                }
            }
            if (hmul!=1) { // horizontal
                CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis2, axis2*hmul);
                CGEventSetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis2, fixedpt_axis2*hmul);
                CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis2, point_axis2*hmul);
                if (ioHidEventRef) {
                    IOHIDEventSetFloatValue(ioHidEventRef, kIOHIDEventFieldScrollX, iohid_axis2*vmul);
                }
            }

            if (ioHidEventRef) {
                CFRelease(ioHidEventRef);
            }
        }
        else
        {
            [tap enableTap];
        }
    
        [tap->logger logEventType:type forKey:@"type"];
        [tap->logger logParams];
    }
    
    return eventRef;
}

@interface MouseTap ()
@property CFMachPortRef activeTapPort;
@property CFRunLoopSourceRef activeTapSource;
@property CFMachPortRef passiveTapPort;
@property CFRunLoopSourceRef passiveTapSource;
@end

@implementation MouseTap

- (void)setActive:(BOOL)state
{
    if (state) {
        [self start];
    }
    else {
        [self stop];
    }
}

- (BOOL)isActive
{
    return self.activeTapSource&&self.passiveTapSource&&self.activeTapPort&&self.passiveTapPort;
}

- (void)start
{
    if([self isActive])
        return;

    [self willChangeValueForKey:kKeyActive];

    // initialise
    _preventReverseOtherApp=[[NSUserDefaults standardUserDefaults] boolForKey:@"ReverseOnlyRawInput"];

    // clear state
    touching=0;
    lastTouchTime=0;
    lastSource=0;
    
    /* We use a separate passive tap to monitor gesture events, because using an
     active tap to do so causes various problems:
        - Triggers additional permissons dialogs when interacting with authorization services dialogs
        - Interferes with "shake to locate cursor" (when using Trackpad)
        - Interferes with the 2-finger "show notificaton center" gesture */
    self.passiveTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
                                                   kCGTailAppendEventTap,
                                                   kCGEventTapOptionListenOnly,
                                                   NSEventMaskGesture,
                                                   _callback,
                                                   (__bridge void *)(self));
    NSLog(@"passive tap port %p", self.passiveTapPort);

    // active tap, for modifying scroll events
    // this one requires user privacy permissions
    self.activeTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
                                           kCGTailAppendEventTap,
                                           kCGEventTapOptionDefault,
                                           NSEventMaskScrollWheel,
                                           _callback,
                                           (__bridge void *)(self));
    NSLog(@"active tap port %p", self.activeTapPort);

    // now create sources and add to run loop
    if (self.passiveTapPort && self.activeTapPort) {
        NSLog(@"Got ports");
        self.passiveTapSource = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.passiveTapPort, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), self.passiveTapSource, kCFRunLoopCommonModes);
        self.activeTapSource = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.activeTapPort, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), self.activeTapSource, kCFRunLoopCommonModes);
    }
    else {
        NSLog(@"Didn't get ports");
        [self stop];
    }

    [self didChangeValueForKey:kKeyActive];

    if ([self isActive]) {
        [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap started"];
    }
    else {
        [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap failed to start"];
    }
}

- (void)stop
{
    [self willChangeValueForKey:kKeyActive];

    if (self.activeTapSource) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), self.activeTapSource, kCFRunLoopCommonModes);
        CFRelease(self.activeTapSource);
        self.activeTapSource=nil;
    }

    if (self.activeTapPort) {
        CFMachPortInvalidate(self.activeTapPort);
        CFRelease(self.activeTapPort);
        self.activeTapPort=nil;
    }

    if (self.passiveTapSource) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), self.passiveTapSource, kCFRunLoopCommonModes);
        CFRelease(self.passiveTapSource);
        self.passiveTapSource=nil;
    }

    if (self.passiveTapPort) {
        CFMachPortInvalidate(self.passiveTapPort);
        CFRelease(self.passiveTapPort);
        self.passiveTapPort=nil;
    }

    [self didChangeValueForKey:kKeyActive];

    [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap stopped"];
}

// called to re-enable the tap if it has become disabled for some reason
- (void)enableTap
{
    if (self.activeTapPort&&!CGEventTapIsEnabled(self.activeTapPort)) {
        CGEventTapEnable(self.activeTapPort, YES);
    }
    if (self.passiveTapPort&&!CGEventTapIsEnabled(self.passiveTapPort)) {
        CGEventTapEnable(self.passiveTapPort, YES);
    }
}


@end
