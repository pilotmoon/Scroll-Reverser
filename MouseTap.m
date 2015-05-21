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
static BOOL _pidIsWacom(const pid_t pid)
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
    
    // look it up
    const BOOL pidIsWacom=[[_bundleIdForPID(pid) lowercaseString] rangeOfString:@"wacom"].length>0;
    if (pidIsWacom)
    {
        lastKnownWacomPid=pid;
    }
    return pidIsWacom;
}

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
        const uint64_t time=nanoseconds();
        
        if (type==NSEventTypeGesture)
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
        else if (type==NSScrollWheel)
        {
            // get the scrolling deltas
            const int64_t pixel_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
            const int64_t pixel_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
            const int64_t line_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
            const int64_t line_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
            const double fixedpt_axis1=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
            const double fixedpt_axis2=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);
            [tap->logger logSignedInteger:pixel_axis1 forKey:@"y_px"];
            [tap->logger logSignedInteger:pixel_axis2 forKey:@"x_px"];
         
            // get source pid
            const uint64_t pid=CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
            [tap->logger logUnsignedInteger:pid forKey:@"pid"];
            
            // get and reset fingers touching
            const NSUInteger touching=tap->touching;
            [tap->logger logUnsignedInteger:touching forKey:@"touching"];
            tap->touching=0;
            
            // calculate elapsed time since touch
            const uint64_t touchElapsed=(time-tap->lastTouchTime);
            [tap->logger logNanoseconds:touchElapsed forKey:@"touchElapsed"];
            
            // get phase
            const ScrollPhase phase=_momentumPhaseForEvent(event);
            [tap->logger logPhase:phase forKey:@"phase"];
            
            // work out the event source
            const ScrollEventSource lastSource=tap->lastSource;
            const ScrollEventSource source=(^{
                
                if (CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous)==0)
                {
                    [tap->logger logBool:YES forKey:@"notContinuous"];
                    return ScrollEventSourceMouse; // assume anything not-continuous is a mouse
                }
                
                if (_pidIsWacom(pid))
                {
                    // detect the wacom mouse, which always seems to scroll in multiples of 25
                    const BOOL wacomMouse=_detectWacomMouse?pixel_axis1!=0&&pixel_axis1%25==0&&pixel_axis2==0:NO;
                    [tap->logger logBool:YES forKey:@"wacomDevice"];
                    [tap->logger logBool:wacomMouse forKey:@"wacomMouse"];
                    
                    return wacomMouse?ScrollEventSourceMouse:ScrollEventSourceTablet;
                }
                
                if (touching>=2)
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
                
                if (tap->inverting&&!preventBecauseComingFromOtherApp)
                {
                    switch (source)
                    {
                        case ScrollEventSourceTrackpad:
                            return tap->invertMultiTouch;
                            
                        case ScrollEventSourceTablet:
                            return tap->invertTablet;
                            
                        case ScrollEventSourceMouse:
                        default:
                            return tap->invertOther;
                    }
                }
                else {
                    return NO;
                }
            })();
            
            [tap->logger logBool:invert forKey:@"reversing"];
            [tap->logger logSource:lastSource forKey:@"lastSource"];
            [tap->logger logSource:source forKey:@"source"];

            if(source!=lastSource) {
                [tap->logger logMessage:@"Source changed!" special:YES];
            }

            /* Do the actual reversing. It's worth noting we have to set them in this order (lines then pixels)
             or we lose smooth scrolling. */
            if (invert)
            {
                if (tap->invertY) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, -line_axis1);
                if (tap->invertX) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, -line_axis2);
                if (tap->invertY) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, -1 * fixedpt_axis1);
                if (tap->invertX) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, -1 * fixedpt_axis2);
                if (tap->invertY) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -pixel_axis1);
                if (tap->invertX) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, -pixel_axis2);
            }
        }
        else if(type==kCGEventTapDisabledByTimeout)
        {
            [tap enableTaps];
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

- (void)resetState
{
//    touching=0;
//    lastTouchTime=0;
//    lastScrollTime=0;
//    lastType=0;
//    lastPhase=0;
//    lastSource=0;
    // TODO ^^
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
    
    CGEventMask eventTypeMask = 0;
    for (NSEventType type = NSLeftMouseDown; type <= NSEventTypeGesture; ++type) {
        switch (type) {
            case NSKeyDown:
            case NSKeyUp:
            case NSFlagsChanged:
                break;
            default:
                eventTypeMask |= NSEventMaskFromType(type);
        }
    }

    // create passive tap for gesture events. we do this because installing
    // an active tap seems to mess with the system 3-finger tap gesture.
    passiveTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
                                                   kCGTailAppendEventTap,
                                                   kCGEventTapOptionListenOnly,
                                                   0,
                                                   callback,
                                                   (__bridge void *)(self));
    
	// create active tap for scroll events (which we modify)
	activeTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
										   kCGTailAppendEventTap,
										   kCGEventTapOptionDefault,
										   eventTypeMask,
										   callback,
										   (__bridge void *)(self));



	// create sources and add to run loop
	passiveTapSource = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, passiveTapPort, 0);
    activeTapSource = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, activeTapPort, 0);

    CFRunLoopAddSource(CFRunLoopGetMain(), passiveTapSource, kCFRunLoopCommonModes);
    CFRunLoopAddSource(CFRunLoopGetMain(), activeTapSource, kCFRunLoopCommonModes);
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
