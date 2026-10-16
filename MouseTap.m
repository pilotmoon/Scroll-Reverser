// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "MouseTap.h"
#import "CoreFoundation/CoreFoundation.h"
#import "TapLogger.h"
#import "AppDelegate.h"
#import "ScrollSource.h"
#import "SourceTable.h"

static NSString *const kKeyActive=@"active";

// The tap's state, for the callback. Private to this file.
@interface MouseTap () {
@public
    ScrollSourceIdentifier *_sourceIdentifier;
    SourceTable *_sourceTable;
}
@property CFMachPortRef activeTapPort;
@property CFRunLoopSourceRef activeTapSource;
@end

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

static CGEventRef _callback(CGEventTapProxy proxy,
                           CGEventType type,
                           CGEventRef eventRef,
                           void *userInfo)
{
    @autoreleasepool
    {
        MouseTap *const tap=(__bridge MouseTap *)userInfo;
        // Tap-disabled notifications are control messages, not NSEvents. Converting
        // them first throws an exception and prevents the tap from recovering.
        if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
            [tap enableTap];
            [tap->logger logEventType:type forKey:@"type"];
            [tap->logger logParams];
            return eventRef;
        }
        if (!eventRef || type != kCGEventScrollWheel) {
            return eventRef;
        }
        NSEvent *const event=[NSEvent eventWithCGEvent:eventRef];
        IOHIDEventRef const ioHidEventRef=CGEventCopyIOHIDEvent(eventRef);

        // has the system applied natural scrolling to this event? (1=natural, 0=classic)
        const BOOL natural=!![event isDirectionInvertedFromDevice];
        [tap->logger logBool:natural forKey:@"ifd"];

        // is continuous (magic mouse and magic trackpad scrolling is continuous)
        const BOOL continuous=!!CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventIsContinuous);
        [tap->logger logBool:continuous forKey:@"continuous"];

        // get the scrolling deltas
        const int64_t axis1=CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis1);
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

        // get phase
        if (tap->logger) {
            [tap->logger logPhase:_momentumPhaseForEvent(eventRef) forKey:@"phase"];
        }

        // the source, identified by the HID event sender or posting process, and its settings
        ScrollSource *const source=[tap->_sourceIdentifier sourceForHIDEvent:ioHidEventRef pid:(pid_t)pid continuous:continuous];
        SourceRow *const row=[tap->_sourceTable recordSource:source natural:natural amount:llabs(point_axis1)+llabs(point_axis2)];
        if (tap->logger) {
            [tap->logger logObject:ioHidEventRef?[NSString stringWithFormat:@"0x%llx", IOHIDEventGetSenderID(ioHidEventRef)]:@"-" forKey:@"sender"];
            [tap->logger logObject:source.key forKey:@"sourcekey"];
        }
        // what to change, by the row's settings
        const SourceAdjustment adjustment=[row adjustmentForNatural:natural];
        const BOOL reverseVertical=adjustment.reverseVertical;
        const BOOL reverseHorizontal=adjustment.reverseHorizontal;
        [tap->logger logBool:reverseVertical forKey:@"reverseV"];
        [tap->logger logBool:reverseHorizontal forKey:@"reverseH"];

        // Adjust discrete scroll wheel? (the step size is 1 for continuous scrolling)
        const NSInteger stepsize=adjustment.stepSize;
        // (shift+scroll with a wheel mouse arrives here already converted to horizontal)
        const BOOL vDiscreteAdjust=stepsize>1&&llabs(axis1)==1;
        const BOOL hDiscreteAdjust=stepsize>1&&llabs(axis2)==1;
        const NSInteger vstep=vDiscreteAdjust?stepsize:1;
        const NSInteger hstep=hDiscreteAdjust?stepsize:1;
        [tap->logger logSignedInteger:vstep forKey:@"vstep"];
        [tap->logger logSignedInteger:hstep forKey:@"hstep"];

        // Calculate signed multiplier to apply
        const NSInteger vmul=reverseVertical?-vstep:vstep;
        const NSInteger hmul=reverseHorizontal?-hstep:hstep;

        /* Do the actual reversing. It's worth noting we have to set the point values second, or we lose smooth scrolling.
         This is because setting DeltaAxis causes macos to internally modify PointDeltaAxis (8x multiplier on DeltaAxis
         value) and FixedPtDeltaAxis (1x multiplier). */
        if (vDiscreteAdjust||vmul!=1) { // vertical
            CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis1, axis1*vmul);
        }
        if (!vDiscreteAdjust&&vmul!=1) { // vertical - only set these if not doing discrete adjust
            CGEventSetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis1, fixedpt_axis1*vmul);
            CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis1, point_axis1*vmul);
            if (ioHidEventRef) {
                IOHIDEventSetFloatValue(ioHidEventRef, kIOHIDEventFieldScrollY, iohid_axis1*vmul);
            }
        }
        if (hDiscreteAdjust||hmul!=1) { // horizontal
            CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis2, axis2*hmul);
        }
        if (!hDiscreteAdjust&&hmul!=1) { // horizontal - only set these if not doing discrete adjust
            CGEventSetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis2, fixedpt_axis2*hmul);
            CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis2, point_axis2*hmul);
            if (ioHidEventRef) {
                IOHIDEventSetFloatValue(ioHidEventRef, kIOHIDEventFieldScrollX, iohid_axis2*hmul);
            }
        }

        if (ioHidEventRef) {
            CFRelease(ioHidEventRef);
        }
        [tap->logger logEventType:type forKey:@"type"];
        [tap->logger logParams];
    }

    return eventRef;
}

@implementation MouseTap

- (instancetype)initWithSourceTable:(SourceTable *)sourceTable
{
    self=[super init];
    if (self) {
        _sourceIdentifier=[[ScrollSourceIdentifier alloc] init];
        _sourceTable=sourceTable;
    }
    return self;
}

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
    return self.activeTapSource&&self.activeTapPort;
}

- (void)start
{
    if([self isActive])
        return;

    [self willChangeValueForKey:kKeyActive];
    [self createTap];
    [self didChangeValueForKey:kKeyActive];
}

- (void)stop
{
    [self willChangeValueForKey:kKeyActive];
    [self destroyTap];
    [self didChangeValueForKey:kKeyActive];
}

- (void)createTap
{
    // active tap, for modifying scroll events
    // this one requires user privacy permissions
    self.activeTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
                                           kCGTailAppendEventTap,
                                           kCGEventTapOptionDefault,
                                           NSEventMaskScrollWheel,
                                           _callback,
                                           (__bridge void *)(self));
    NSLog(@"active tap port %p", self.activeTapPort);

    // now create the source and add to run loop
    if (self.activeTapPort) {
        NSLog(@"Got port");
        self.activeTapSource = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.activeTapPort, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), self.activeTapSource, kCFRunLoopCommonModes);
    }
    else {
        NSLog(@"Didn't get port");
        [self destroyTap];
    }

    if ([self isActive]) {
        [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap started"];
    }
    else {
        [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap failed to start"];
    }
}

- (void)destroyTap
{
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

    [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap stopped"];
}

// called to re-enable the tap if it has become disabled for some reason
- (void)enableTap
{
    if (self.activeTapPort&&!CGEventTapIsEnabled(self.activeTapPort)) {
        CGEventTapEnable(self.activeTapPort, YES);
    }
}


@end
