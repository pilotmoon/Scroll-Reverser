#import "MouseTap.h"
#import "CoreFoundation/CoreFoundation.h"
#import "TapLogger.h"
#import "AppDelegate.h"

#define MAGIC_NUMBER (0x7363726F726576) // "scrorev" in hex

static BOOL _preventReverseOtherApp;
static BOOL _detectWacomMouse;

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
            return ScrollPhaseEnd;
        default:
            return ScrollPhaseNormal;
    }
}

static void clearTouches(MouseTap *const tap)
{
    [tap->touches removeAllObjects];
    [tap->logger logBool:YES forKey:@"touchesCleared"];
}

static CGEventRef gestureCallback(CGEventTapProxy proxy,
                                  CGEventType type,
                                  CGEventRef event,
                                  void *userInfo)
{
    @autoreleasepool
    {
        MouseTap *const tap=(__bridge MouseTap *)userInfo;
        [tap->logger logEventType:type forKey:@"type"];
        
        const UInt32 ticks=TickCount();
        const UInt32 ticksElapsed=ticks-tap->lastGestureTicks;
        tap->lastGestureTicks=ticks;
        [tap->logger logUnsignedInteger:ticksElapsed forKey:@"elapsed"];
        
        if (type==NSEventTypeGesture)
        {
            /* How many fingers on the trackpad? Starting from a certain 10.10.2 preview,
             OS X started inserting extra events with no touches, in between events with touches. So
             This bit had to get a but more complicated so as to ignore the rogue 'zero touches' events. */
            NSEvent *ev=[NSEvent eventWithCGEvent:event];
            //[tap->logger logObject:ev forKey:@"ev"];
            //[tap->logger logUnsignedInteger:[ev subtype] forKey:@"subtype"];
            
            // count fingers currently on the pad
            NSSet *touching=[ev touchesMatchingPhase:NSTouchPhaseTouching inView:nil];
            [tap->logger logCount:touching forKey:@"touching"];
            if ([touching count]==0) {
                if (tap->rawZeroCount<5) {
                    // count how many times touchesMatchingPhase reported zero touches even when there really are touches.
                    // I have observed runs of 3 in tests on 10.10.2 preview, but no more.
                    // allowing 5 here in case of future awkwardness.
                    tap->rawZeroCount+=1;
                }
                else {
                    // sometimes we miss the 'touch ended' and touches get stuck in our cache. so we clear them out.
                    clearTouches(tap);
                }
            }
            else {
                tap->rawZeroCount=0;
                clearTouches(tap);
                
                for (NSTouch *touch in touching) {
                    const id identity=[touch identity];
                    [tap->touches addObject:identity];
                    [tap->logger logObject:identity forCountedKey:@"+t"];
                }
            }
            
            // subtract fingers removed from the pad
            NSSet *ended=[ev touchesMatchingPhase:NSTouchPhaseEnded|NSTouchPhaseCancelled inView:nil];
            for (NSTouch *touch in ended) {
                const id identity=[touch identity];
                [tap->touches removeObject:[touch identity]];
                [tap->logger logObject:identity forCountedKey:@"-t"];
            }
            
            tap->fingers=[tap->touches count];
            
            [tap->logger logUnsignedInteger:tap->rawZeroCount forKey:@"rzc"];
            [tap->logger logUnsignedInteger:tap->fingers forKey:@"f"];
        }
        else if(type==kCGEventTapDisabledByTimeout)
        {
            [tap enableTaps];
        }
        
        [tap->logger logParams];
    }
    
    return NULL;
}

static CGEventRef scrollCallback(CGEventTapProxy proxy,
                                 CGEventType type,
                                 CGEventRef event,
                                 void *userInfo)
{
    @autoreleasepool
    {
        MouseTap *const tap=(__bridge MouseTap *)userInfo;
        [tap->logger logEventType:type forKey:@"type"];
        
        const UInt32 ticks=TickCount(); // about 1/60 of a sec
        const UInt32 ticksElapsed=ticks-tap->lastScrollTicks;
        tap->lastScrollTicks=ticks;
        
        [tap->logger logUnsignedInteger:ticksElapsed forKey:@"elapsed"];
        
        if (type==NSScrollWheel)
        {
            // get source pid
            const uint64_t pid=CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
            [tap->logger logUnsignedInteger:pid forKey:@"pid"];
            
            // get the scrolling deltas
            const int64_t pixel_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
            const int64_t pixel_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
            const int64_t line_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
            const int64_t line_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
            const double fixedpt_axis1=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
            const double fixedpt_axis2=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);

            [tap->logger logSignedInteger:pixel_axis1 forKey:@"y_px"];
            [tap->logger logSignedInteger:pixel_axis2 forKey:@"x_px"];
            // [tap->logger logSignedInteger:line_axis1 forKey:@"y_line"];
            // [tap->logger logSignedInteger:line_axis1 forKey:@"x_line"];
            // [tap->logger logDouble:fixedpt_axis1 forKey:@"y_fp"];
            // [tap->logger logDouble:fixedpt_axis2 forKey:@"x_fp"];
            
            // default source is "Other" i.e. not a Trackpad, not a Tablet, but a Mouse.
            ScrollEventSource source=ScrollEventSourceOther;
            do
            {
                // assume non-continuous events are never from a trackpad or tablet
                if (CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous)==0) {
                    [tap->logger logBool:YES forKey:@"notContinuous"];
                    break;
                }
                
                // check if wacom device, which could be tablet or mouse
                if (_pidIsWacomTablet(pid))
                {
                    // detect the wacom mouse, which always seems to scroll in multiples of 25
                    const BOOL wacomMouse=_detectWacomMouse?pixel_axis1!=0&&pixel_axis1%25==0&&pixel_axis2==0:NO;
                    if (!wacomMouse) {
                        source=ScrollEventSourceTablet;
                    }
                    
                    [tap->logger logBool:YES forKey:@"wacomDevice"];
                    [tap->logger logBool:wacomMouse forKey:@"wacomMouse"];
                    break;
                }
                
                // now do the bit where we work out if it is a trackpad or not
                const ScrollPhase phase=_momentumPhaseForEvent(event);
                
                [tap->logger logPhase:phase forKey:@"phase"];
                [tap->logger logUnsignedInteger:tap->fingers forKey:@"f"];
                [tap->logger logUnsignedInteger:tap->sampledFingers forKey:@"sf"];
                [tap->logger logUnsignedInteger:tap->zeroCount forKey:@"zc"];
                
                if (phase==ScrollPhaseMomentum)
                {
                    /* during momentum phase we can assume less than 2 touches on pad.
                    it's probably a good idea to clear the cache here. */
                    clearTouches(tap);
                }
                
                /* Should we sample the number of fingers now? The whole point of this is to only sample fingers when user is actually
                 * scrolling, not during the momentum phase. Unfortunately the system cannot be relied upon to always send correct
                 * finger signals (four finger swipes for example can mess things up, although this seems fixed on Yosemite) so we
                 * use some timing and other indicators. Still room for improvement here. */
                if (phase==ScrollPhaseNormal&&(tap->lastPhase!=ScrollPhaseNormal||tap->sampledFingers<2||tap->zeroCount>2||ticksElapsed>20))
                {
                    [tap->logger logBool:YES forKey:@"sampling"];
                    tap->sampledFingers=tap->fingers;
                }
                
                // Assume Trackpad source when 2 fingers are seen on the pad.
                if (tap->sampledFingers>=2)
                {
                    source=ScrollEventSourceTrackpad;
                }
                
                // Count of how many times we have seen no fingers on the pad.
                if (tap->fingers>=2)
                {
                    tap->zeroCount=0;
                }
                else
                {
                    tap->zeroCount+=1;
                }
                
                tap->lastPhase=phase;
                
            } while(0);
            
            [tap->logger logSource:source forKey:@"source"];
            
            // don't reverse scrolling we have already reversed
            const int64_t ud=CGEventGetIntegerValueField(event, kCGEventSourceUserData);
            const BOOL preventBecauseOfMagicNumber=ud==MAGIC_NUMBER;
            
            /* Don't reverse scrolling coming from another app (if that setting is on).
             * This is useful if Scroll Reverser is running inside a remote desktop, to ignore scrolling coming from
             * the controlling host but still reverse local scrolling. */
            const BOOL preventBecauseComingFromOtherApp=_preventReverseOtherApp?pid!=0:NO;
            
            // finally, do we reverse the scroll or not?
            BOOL invert=NO;
            if (tap->inverting&&!(preventBecauseOfMagicNumber||preventBecauseComingFromOtherApp))
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

            [tap->logger logBool:invert forKey:@"outcome"];
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
                
                // set out user data flag
                CGEventSetIntegerValueField(event, kCGEventSourceUserData, MAGIC_NUMBER);
            }
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
    touches=[NSMutableSet set];
    fingers=sampledFingers=rawZeroCount=zeroCount=0;
    lastScrollTicks=0;
    lastPhase=0;
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
										   scrollCallback,
										   (__bridge void *)(self));

    // create passive tap for gesture events. we do this because installing
    // an active tap seems to mess with the system 3-finger tap gesture.
    passiveTapPort=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
                                                  kCGTailAppendEventTap,
                                                  kCGEventTapOptionListenOnly,
                                                  NSEventMaskGesture,
                                                  gestureCallback,
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
    
    touches=nil;
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
