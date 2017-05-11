// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "MouseTap.h"
#import "CoreFoundation/CoreFoundation.h"
#import "TapLogger.h"
#import "AppDelegate.h"
#import <mach/mach_time.h>

static BOOL _preventReverseOtherApp;
static BOOL _detectWacomMouse;

#define MILLISECOND ((uint64_t)1000000)

/*
 Get the bundle identifier for the given pid.
 */
static NSString *bundleIdForPID(const pid_t pid)
{
	ProcessSerialNumber psn={0, 0};
	OSStatus status=GetProcessForPID(pid, &psn);
	if (status==noErr)
	{
        NSDictionary * dict=(NSDictionary *)CFBridgingRelease(ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask));
		return dict[(NSString *)kCFBundleIdentifierKey];
	}
	return nil;
}

/*
 Is the pid a wacom tablet? Crude method.
 */
static BOOL pidIsWacom(const pid_t pid, MouseTap *const tap)
{
    // zero is the common case
    if (pid==0) {
        return NO;
    }
    
    // short cut
    static pid_t lastKnownWacomPid=0;
    if (pid==lastKnownWacomPid) {
        return YES;
    }
    
    // get bid
    NSString *const bid=bundleIdForPID(pid);
    [tap->logger logObject:bid forKey:@"bid"];
    
    // is it wacom?
    const BOOL pidIsWacom=[[bid lowercaseString] rangeOfString:@"wacom"].length>0;
    if (pidIsWacom)
    {
        lastKnownWacomPid=pid;
    }
    return pidIsWacom;
}

static ScrollPhase momentumPhaseForEvent(CGEventRef event)
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

static uint64_t nanoseconds(void)
{
    const uint64_t abstime = mach_absolute_time();
    const Nanoseconds nanotime = AbsoluteToNanoseconds( *(AbsoluteTime *) &abstime );
    return * (uint64_t *) &nanotime;
}


static CGEventRef callback(CGEventTapProxy proxy,
                           CGEventType type,
                           CGEventRef event,
                           void *userInfo)
{
    @autoreleasepool
    {
        MouseTap *const tap=(__bridge MouseTap *)userInfo;
        const uint64_t time=nanoseconds();
        
        if (type==(CGEventType)NSEventTypeGesture)
        {
            const NSUInteger touching=[[[NSEvent eventWithCGEvent:event] touchesMatchingPhase:NSTouchPhaseTouching inView:nil] count];
        
            if (touching>=2) {
                [tap->logger logUnsignedInteger:touching forKey:@"touching"];
                tap->lastTouchTime=time;
                tap->touching=MAX(tap->touching, touching);
            }
            else {
                return event; // totally ignore zero or one touch events
            }
        }
        else if (type==(CGEventType)NSScrollWheel)
        {
            // get the scrolling deltas
            const int64_t pixel_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
            const int64_t pixel_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
            const int64_t line_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
            const int64_t line_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
            const double fixedpt_axis1=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
            const double fixedpt_axis2=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);
            [tap->logger logSignedInteger:pixel_axis1 forKey:@"y"];
            [tap->logger logSignedInteger:pixel_axis2 forKey:@"x"];
         
            // get source pid
            const uint64_t pid=CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
            [tap->logger logUnsignedInteger:pid forKey:@"pid"];
            
            // calculate elapsed time since touch
            const uint64_t touchElapsed=(time-tap->lastTouchTime);
            [tap->logger logNanoseconds:touchElapsed forKey:@"touchElapsed"];
            
            // get and reset fingers touching
            const NSUInteger touching=tap->touching;
            [tap->logger logUnsignedInteger:touching forKey:@"touching"];
            tap->touching=0;

            // get phase
            const ScrollPhase phase=momentumPhaseForEvent(event);
            [tap->logger logPhase:phase forKey:@"phase"];
            
            // work out the event source
            const ScrollEventSource lastSource=tap->lastSource;
            const ScrollEventSource source=(^{
                
                if (CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous)==0)
                {
                    [tap->logger logBool:YES forKey:@"notContinuous"];
                    return ScrollEventSourceMouse; // assume anything not-continuous is a mouse
                }
                
                if (pidIsWacom((pid_t)pid, tap))
                {
                    // detect the wacom mouse, which always seems to scroll in multiples of 25
                    const BOOL wacomMouse=_detectWacomMouse?pixel_axis1!=0&&pixel_axis1%25==0&&pixel_axis2==0:NO;
                    [tap->logger logBool:YES forKey:@"wacomDevice"];
                    [tap->logger logBool:wacomMouse forKey:@"wacomMouse"];
                    
                    return wacomMouse?ScrollEventSourceMouse:ScrollEventSourceTablet;
                }
                
                if (touching>=2 && touchElapsed<(MILLISECOND*222))
                {
                    [tap->logger logBool:YES forKey:@"usingTouches"];
                    return ScrollEventSourceTrackpad;
                }
                
                if (phase==ScrollPhaseNormal && touchElapsed>(MILLISECOND*333))
                {
                    [tap->logger logBool:YES forKey:@"usingTouchElapsed"];
                    return ScrollEventSourceMouse;
                }
                
                // not enough information to decide. assume the same as last time. ha!
                [tap->logger logBool:YES forKey:@"usingPrevious"];
                return tap->lastSource;
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
                            
                        case ScrollEventSourceTablet:
                            return [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseTablet];
                            
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

            /* Do the actual reversing. It's worth noting we have to set them in this order (lines then pixels)
             or we lose smooth scrolling. */
            if (invert)
            {
                const BOOL reverseX=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseHorizontal];
                const BOOL reverseY=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseVertical];
                if (reverseY) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, -line_axis1);
                if (reverseX) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, -line_axis2);
                if (reverseY) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, -1 * fixedpt_axis1);
                if (reverseX) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, -1 * fixedpt_axis2);
                if (reverseY) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -pixel_axis1);
                if (reverseX) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, -pixel_axis2);
            }
        }
        else
        {
            [tap enableTap];
        }
    
        [tap->logger logEventType:type forKey:@"type"];
        [tap->logger logParams];
	}
    
    return event;
}

@implementation MouseTap

- (BOOL)isActive
{
	return activeTapSource&&passiveTapSource&&activeTapPort&&passiveTapPort;
}

- (void)start
{
	if([self isActive])
		return;

    // initialise
    _preventReverseOtherApp=[[NSUserDefaults standardUserDefaults] boolForKey:@"ReverseOnlyRawInput"];
    _detectWacomMouse=![[NSUserDefaults standardUserDefaults] boolForKey:@"DisableWacomMouseDetection"];

    // clear state
    touching=0;
    lastTouchTime=0;
    lastSource=0;
    
    /* We use a separate passive tap to monitor gesture events, because using an
     active tap to do so causes various problems:
        - Triggers additional permissons dialogs when interacting with authorization services dialogs
        - Interferes with "shake to locate cursor" (when using Trackpad)
        = Interferes with the 2-finger "show notificaton center" gesture */
    CGEventMask passiveEventMask=NSEventMaskGesture;
    passiveTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
                                                   kCGTailAppendEventTap,
                                                   kCGEventTapOptionListenOnly,
                                                   passiveEventMask,
                                                   callback,
                                                   (__bridge void *)(self));
	passiveTapSource = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, passiveTapPort, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), passiveTapSource, kCFRunLoopCommonModes);
    
    // active tap, for modifying scroll events
    CGEventMask activeEventMask=NSEventMaskScrollWheel;
    activeTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
										   kCGTailAppendEventTap,
										   kCGEventTapOptionDefault,
										   activeEventMask,
										   callback,
										   (__bridge void *)(self));
	activeTapSource = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, activeTapPort, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), activeTapSource, kCFRunLoopCommonModes);

    [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap started"];
}

- (void)stop
{
	if (![self isActive])
		return;
	
	CFRunLoopRemoveSource(CFRunLoopGetMain(), activeTapSource, kCFRunLoopCommonModes);
    CFMachPortInvalidate(activeTapPort);
    CFRelease(activeTapSource);
    activeTapSource=nil;
    CFRelease(activeTapPort);
    activeTapPort=nil;
    
    CFRunLoopRemoveSource(CFRunLoopGetMain(), passiveTapSource, kCFRunLoopCommonModes);
    CFMachPortInvalidate(passiveTapPort);
    CFRelease(passiveTapSource);
    passiveTapSource=nil;
    CFRelease(passiveTapPort);
	passiveTapPort=nil;
    
    [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap stopped"];
}

- (void)enableTap
{
    if (!CGEventTapIsEnabled(activeTapPort)) {
        CGEventTapEnable(activeTapPort, YES);
    }
    if (!CGEventTapIsEnabled(passiveTapPort)) {
        CGEventTapEnable(passiveTapPort, YES);
    }
}

- (void)resetTap
{
    [self stop];
    [self start];
    [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap reset"];
}

@end
