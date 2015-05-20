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

/* 
 We abstract the system defined scrolling phases into these possibilities.
 */
typedef enum {
    ScrollPhaseNormal=0, // fingers on pad
    ScrollPhaseMomentum, // fingers off pad, but scrolling with momentum
    ScrollPhaseEnd       // scrolling ended
} ScrollPhase;

static ScrollPhase _momentumPhaseForEvent(CGEventRef event)
{
    ScrollPhase result=ScrollPhaseNormal;
    
    const NSEventPhase momentumPhase=[[NSEvent eventWithCGEvent:event] momentumPhase];
    
    if (momentumPhase==NSTouchPhaseStationary) {
        result=ScrollPhaseMomentum;
    }
    else if (momentumPhase==NSTouchPhaseEnded) {
        result=ScrollPhaseEnd;
    }
    return result;
}

// This is called every time there is a scroll event. It has to be efficient.
static CGEventRef eventTapCallback(CGEventTapProxy proxy,
                                   CGEventType type,
                                   CGEventRef event,
                                   void *userInfo)
{
    @autoreleasepool {
		MouseTap *tap=(__bridge MouseTap *)userInfo;
        void(^clearTouches)(void)=^{
            [tap->logger logBool:YES forKey:@"touchesCleared"];
            [tap->touches removeAllObjects];
        };
        
        [tap->logger logUnsignedInteger:type forKey:@"eventType"];
        
        if (type==NSEventTypeGesture)
        {
            /* How many fingers on the trackpad? Starting from a certain 10.10.2 preview,
             OS X started inserting extra events with no touches, in between events with touches. So
             This bit had to get a but more complicated so as to ignore the rogue 'zero touches' events. */
            NSEvent *ev=[NSEvent eventWithCGEvent:event];
            
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
                    clearTouches();
                }
            }
            else {
                tap->rawZeroCount=0;
                clearTouches();
                
                for (NSTouch *touch in touching) {
                    const id identity=[touch identity];
                    [tap->touches addObject:identity];
                    [tap->logger logObject:identity forCountedKey:@"+touch"];
                }
            }
            
            // subtract fingers removed from the pad
            NSSet *ended=[ev touchesMatchingPhase:NSTouchPhaseEnded|NSTouchPhaseCancelled inView:nil];
            for (NSTouch *touch in ended) {
                const id identity=[touch identity];
                [tap->touches removeObject:[touch identity]];
                [tap->logger logObject:identity forCountedKey:@"-touch"];
            }
            
            tap->fingers=[tap->touches count];
            
            [tap->logger logUnsignedInteger:tap->rawZeroCount forKey:@"rawZeroCount"];
            [tap->logger logUnsignedInteger:tap->fingers forKey:@"fingers"];
        }
        else if (type==NSScrollWheel)
        {
            // get the scrolling deltas
            const int64_t pixel_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
            const int64_t pixel_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
            int64_t line_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
            int64_t line_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
            double fixedpt_axis1=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
            double fixedpt_axis2=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);
            
            // check if wacom device
            const uint64_t pid=CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
            const BOOL wacomDevice=pid&&_pidIsWacomTablet(pid);

            // detect the wacom mouse, which always seems to scroll in multiples of 25
            const BOOL wacomMouse=_detectWacomMouse?pixel_axis1%25==0&&pixel_axis2==0:NO;
            
            // get the continuous flag
            const BOOL continuous=CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous)!=0;

            // default source is "Other" i.e. not a Trackpad, not a Tablet, but a Mouse.
            ScrollEventSource source=ScrollEventSourceOther;
            
            // assume non-continuous events are never from a trackpad or tablet
            if (continuous)
            {
                if (wacomDevice&&!wacomMouse)
                {
                    source=ScrollEventSourceTablet;
                }
                else // detect trackpad
                {
                    const ScrollPhase phase=_momentumPhaseForEvent(event);
                    const UInt32 ticks=TickCount(); // about 1/60 of a sec
                    const UInt32 ticksElapsed=ticks-tap->lastScrollTicks;
                    
                    if (phase==ScrollPhaseMomentum) {
                        // during momentum phase we can assume less than 2 touches on pad. it's probably a good idea to clear the cache here.
                        clearTouches();
                    }
                    
                    /* Should we sample the number of fingers now? The whole point of this is to only sample fingers when user is actually
                     * scrolling, not during the momentum phase. Unfortunately the system cannot be relied upon to always send correct
                     * finger signals (four finger swipes for example can mess things up, although this seems fixed on Yosemite) so we
                     * use some timing and other indicators. Still room for improvement here. */
                    if (phase==ScrollPhaseNormal&&(tap->lastPhase!=ScrollPhaseNormal||tap->sampledFingers<2||tap->zeroCount>2||ticksElapsed>20))
                    {
                        tap->sampledFingers=tap->fingers;
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
                    
                    // Assume Trackpad source when 2 fingers are seen on the pad.
                    if (tap->sampledFingers>=2)
                    {
                        source=ScrollEventSourceTrackpad;
                    }
                    
                    tap->lastPhase=phase;
                    tap->lastScrollTicks=TickCount();
                }
            }
            
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

//            NSString *logstr=[NSString stringWithFormat:@"pid %@ cont %@ dy %@ dx %@ wDevice %@ wMouse %@ fingers %@ sampled %@ source %@ invert %@",
//                  @(pid), @(continuous), @(pixel_axis1), @(pixel_axis2), @(wacomDevice), @(wacomMouse), @(tap->fingers), @(tap->sampledFingers), @(source), @(invert)];
//            [tap->logger logMessage:logstr];

        }
        else if(type==kCGEventTapDisabledByTimeout)
        {
            // This can happen sometimes. (Not sure why.) 
            [tap enableTap:TRUE]; // Just re-enable it.
        }	
        
        [tap->logger logParams];
		return event;
	}
}

@implementation MouseTap

- (BOOL)isActive
{
	return source&&port;
}

- (NSString *)stateString
{
    NSString *(^val)(NSString *, unsigned long) = ^(NSString *label, unsigned long val) {
        return [NSString stringWithFormat:@"[%@ %@]", label, @(val)];
    };
    NSString *temp=val(@"touches", [touches count]);
    temp=[temp stringByAppendingString:val(@"f", fingers)];
    temp=[temp stringByAppendingString:val(@"sf", sampledFingers)];
    temp=[temp stringByAppendingString:val(@"rzc", rawZeroCount)];
    temp=[temp stringByAppendingString:val(@"zc", zeroCount)];
    temp=[temp stringByAppendingString:val(@"lst", lastScrollTicks)];
    temp=[temp stringByAppendingString:val(@"lp", lastPhase)];
    return temp;
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

	// create mach port
	port=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
										   kCGTailAppendEventTap,
										   kCGEventTapOptionDefault,
										   NSScrollWheelMask|NSTabletProximityMask|NSEventMaskGesture,
										   eventTapCallback,
										   (__bridge void *)(self));

	// create source and add to tun loop
	source = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0);
	CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
}

- (void)stop
{
	if (![self isActive])
		return;
	
	CFRunLoopRemoveSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
	CFMachPortInvalidate(port);
	CFRelease(source);
	CFRelease(port);
	source=nil;
	port=nil;
    touches=nil;
}

- (void)enableTap:(BOOL)state
{
	CGEventTapEnable(port, state);
}

@end
