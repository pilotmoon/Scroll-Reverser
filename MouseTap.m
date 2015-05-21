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
static NSString *_bundleIdForPID(const pid_t pid)
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
static BOOL _pidIsWacomTablet(const pid_t pid)
{
    // zero is the common case
    if (pid==0) {
        return NO;
    }
    
    // short cut
    static pid_t lastKnownTabletPid=0;
    if (pid==lastKnownTabletPid) {
        return YES;
    }
    
    // look it up
    NSString *bid=[_bundleIdForPID(pid) lowercaseString];
    const BOOL pidIsTablet=[bid rangeOfString:@"wacom"].length>0;
    if (pidIsTablet)
    {
        lastKnownTabletPid=pid;
        return YES;
    }
    
    return NO;
}

static ScrollPhase _momentumPhaseForEvent(CGEventRef event)
{
    switch ([[NSEvent eventWithCGEvent:event] momentumPhase]) {
        case NSTouchPhaseStationary:
            return ScrollPhaseMomentum;
        case NSTouchPhaseEnded:
        case NSTouchPhaseCancelled:
            return ScrollPhaseEnd;
        default:
            return ScrollPhaseNormal;
    }
}

uint64_t nanoseconds(void)
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
        [tap->logger logEventType:type forKey:@"type"];
        
        const uint64_t time=nanoseconds();
        const uint64_t elapsed=(time-tap->lastEventTime);
        tap->lastEventTime=time;
        [tap->logger logNanoseconds:elapsed forKey:@"elapsed"];
        
        if (type==NSEventTypeGesture)
        {
            // record the current tick count if there are any fingers reported
            // (we get a lot of reports of 0 fingers so ignore those completely)
            const NSUInteger touching=[[[NSEvent eventWithCGEvent:event] touchesMatchingPhase:NSTouchPhaseTouching inView:nil] count];
            if (touching>0) {
                [tap->logger logUnsignedInteger:touching forKey:@"touching"];
                tap->lastSeenFingers=touching;
                tap->lastSeenFingersTime=time;
            }
        }
        else if (type==NSScrollWheel)
        {
            // get source pid
            const uint64_t pid=CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
            
            // get the scrolling deltas
            const int64_t pixel_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
            const int64_t pixel_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
            const int64_t line_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
            const int64_t line_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
            const double fixedpt_axis1=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
            const double fixedpt_axis2=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);

            // now do the bit where we work out if it is a trackpad or not
            const ScrollPhase phase=_momentumPhaseForEvent(event);
            const ScrollPhase lastPhase=tap->lastPhase;
            tap->lastPhase=phase;
            [tap->logger logPhase:phase forKey:@"phase"];
            [tap->logger logPhase:tap->lastPhase forKey:@"lastPhase"];
            
            // default source is "Other" i.e. not a Trackpad, not a Tablet, but a Mouse.
            const ScrollEventSource source=(^{
                // assume non-continuous events are never from a trackpad or tablet
                if (CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous)==0)
                {
                    [tap->logger logBool:YES forKey:@"notContinuous"];
                    return ScrollEventSourceOther;
                }
                
                // check if wacom device, which could be tablet or mouse
                if (_pidIsWacomTablet(pid))
                {
                    // detect the wacom mouse, which always seems to scroll in multiples of 25
                    const BOOL wacomMouse=_detectWacomMouse?pixel_axis1!=0&&pixel_axis1%25==0&&pixel_axis2==0:NO;
                    [tap->logger logBool:YES forKey:@"wacomDevice"];
                    [tap->logger logBool:wacomMouse forKey:@"wacomMouse"];
                    
                    return wacomMouse?ScrollEventSourceOther:ScrollEventSourceTablet;
                }
                
                // only sample fingers when newly in normal phase
                if (phase==ScrollPhaseNormal && (lastPhase!=ScrollPhaseNormal || elapsed<200*MILLISECOND))
                {
                    // only trust fingers number if it came in "very recently"
                    const uint64_t fingersElapsed=time-tap->lastSeenFingersTime;
                    const BOOL fingersValid=fingersElapsed<(MILLISECOND*500);
                    const uint64_t currentFingers=fingersValid?tap->lastSeenFingers:0;

                    [tap->logger logUnsignedInteger:tap->lastSeenFingers forKey:@"lastSeenFingers"];
                    [tap->logger logNanoseconds:tap->lastSeenFingersTime forKey:@"lastSeenFingersTime"];
                    [tap->logger logNanoseconds:fingersElapsed forKey:@"fingersElapsed"];
                    [tap->logger logBool:fingersValid forKey:@"valid"];
                    [tap->logger logUnsignedInteger:currentFingers forKey:@"currentFingers"];
                
                    return currentFingers>=2?ScrollEventSourceTrackpad:ScrollEventSourceOther;
                }
                else {
                    return tap->lastSource;
                }
            })();
            
            // now we have the final source
            tap->lastSource=source;
            
            [tap->logger logUnsignedInteger:pid forKey:@"pid"];
            [tap->logger logSignedInteger:pixel_axis1 forKey:@"y_px"];
            [tap->logger logSignedInteger:pixel_axis2 forKey:@"x_px"];
            [tap->logger logSource:source forKey:@"source"];
            
            /* Don't reverse scrolling coming from another app (if that setting is on).
             This is useful if Scroll Reverser is running inside a remote desktop, to ignore
             scrolling coming from the controlling host but still reverse local scrolling.
             */
            const BOOL preventBecauseComingFromOtherApp=_preventReverseOtherApp?pid!=0:NO;
            
            // finally, do we reverse the scroll or not?
            BOOL invert=NO;
            if (tap->inverting&&!preventBecauseComingFromOtherApp)
            {
                switch (source)
                {
                    case ScrollEventSourceTrackpad:
                        invert=tap->invertMultiTouch;
                        break;
                        
                    case ScrollEventSourceTablet:
                        invert=tap->invertTablet;
                        break;
                        
                    case ScrollEventSourceOther:
                    default:
                        invert=tap->invertOther;
                        break;
                }
            }
            
            if (invert)
            {
                /* Do the actual reversing. It's worth noting we have to set them in this order (lines then pixels)
                 or we lose smooth scrolling. */
                if (tap->invertY) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, -line_axis1);
                if (tap->invertX) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, -line_axis2);
                if (tap->invertY) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, -1 * fixedpt_axis1);
                if (tap->invertX) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, -1 * fixedpt_axis2);
                if (tap->invertY) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -pixel_axis1);
                if (tap->invertX) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, -pixel_axis2);
            }
            
            [tap->logger logBool:invert forKey:@"reversing"];
        }
        else if(type==kCGEventTapDisabledByTimeout)
        {
            [tap enableTaps];
        }	

        [tap->logger logParams];
	}
    
    return event;
}

@implementation MouseTap

- (BOOL)isActive
{
	return activeTapSource&&passiveTapSource&&activeTapPort&&passiveTapPort;
}

- (void)resetState
{
    lastEventTime=0;
    lastSeenFingersTime=0;
    lastSeenFingers=0;
//    sampledFingers=0;
    //TODO
    [(AppDelegate *)[NSApp delegate] logAppEvent:@"Tap state reset"];
}

- (void)start
{
	if([self isActive])
		return;

    // initialise
    _preventReverseOtherApp=[[NSUserDefaults standardUserDefaults] boolForKey:@"ReverseOnlyRawInput"];
    _detectWacomMouse=![[NSUserDefaults standardUserDefaults] boolForKey:@"DisableWacomMouseDetection"];
    [self resetState];

	// create active tap for scroll events (which we modify)
	activeTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
										   kCGTailAppendEventTap,
										   kCGEventTapOptionDefault,
										   NSScrollWheelMask,
										   callback,
										   (__bridge void *)(self));

    // create passive tap for gesture events. we do this because installing
    // an active tap seems to mess with the system 3-finger tap gesture.
    passiveTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
                                                  kCGTailAppendEventTap,
                                                  kCGEventTapOptionListenOnly,
                                                  NSEventMaskGesture,
                                                  callback,
                                                  (__bridge void *)(self));

	// create sources and add to run loop
	activeTapSource = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, activeTapPort, 0);
	passiveTapSource = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, passiveTapPort, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), activeTapSource, kCFRunLoopCommonModes);
    CFRunLoopAddSource(CFRunLoopGetMain(), passiveTapSource, kCFRunLoopCommonModes);
}

- (void)stop
{
	if (![self isActive])
		return;
	
	CFRunLoopRemoveSource(CFRunLoopGetMain(), activeTapSource, kCFRunLoopCommonModes);
	CFRunLoopRemoveSource(CFRunLoopGetMain(), passiveTapSource, kCFRunLoopCommonModes);
    
    CFMachPortInvalidate(activeTapPort);
	CFMachPortInvalidate(passiveTapPort);
    
	CFRelease(activeTapSource);
    CFRelease(passiveTapSource);
	activeTapSource=passiveTapSource=nil;
    
    CFRelease(activeTapPort);
    CFRelease(passiveTapPort);
	activeTapPort=passiveTapPort=nil;
    
    // TODO touches=nil;
}

- (void)enableTaps
{
    if (!CGEventTapIsEnabled(activeTapPort)) {
        CGEventTapEnable(activeTapPort, YES);
    }
    if (!CGEventTapIsEnabled(passiveTapPort)) {
        CGEventTapEnable(passiveTapPort, YES);
    }
}

@end
