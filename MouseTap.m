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
        
        [tap->logger logEventType:type forKey:@"type"];

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
                    clearTouches();
                }
            }
            else {
                tap->rawZeroCount=0;
                clearTouches();
                
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
        else if (type==NSScrollWheel)
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
                const UInt32 ticks=TickCount(); // about 1/60 of a sec
                const UInt32 ticksElapsed=TickCount()-tap->lastScrollTicks;
                
                [tap->logger logPhase:phase forKey:@"phase"];
                [tap->logger logUnsignedInteger:ticksElapsed forKey:@"elapsed"];
                [tap->logger logUnsignedInteger:tap->fingers forKey:@"f"];
                [tap->logger logUnsignedInteger:tap->sampledFingers forKey:@"sf"];
                [tap->logger logUnsignedInteger:tap->zeroCount forKey:@"zc"];
                
                if (phase==ScrollPhaseMomentum)
                {
                    /* during momentum phase we can assume less than 2 touches on pad.
                    it's probably a good idea to clear the cache here. */
                    clearTouches();
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
                tap->lastScrollTicks=ticks;
                
                
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
										   NSScrollWheelMask|NSEventMaskGesture,
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
