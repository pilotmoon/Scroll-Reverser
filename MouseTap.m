#import "MouseTap.h"
#import "CoreFoundation/CoreFoundation.h"

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
        
        if (type==NSEventTypeGesture)
        {
            /* How many fingers on the trackpad? Starting from a certain 10.10.2 preview,
             OS X started inserting extra events with no touches, in between events with touches. So
             This bit had to get a but more complicates so as to ignore the rogue 'zero touches' events. */
            NSEvent *ev=[NSEvent eventWithCGEvent:event];
            
            // count fingers currently on the pad
            NSSet *touching=[ev touchesMatchingPhase:NSTouchPhaseTouching inView:nil];
            if ([touching count]>0) {
                [tap->touches removeAllObjects]; // avoid stale data
                for (NSTouch *touch in touching) {
                    [tap->touches addObject:[touch identity]];
                }
            }
            
            // subtract fingers removed from the pad
            NSSet *ended=[ev touchesMatchingPhase:NSTouchPhaseEnded|NSTouchPhaseCancelled inView:nil];
            for (NSTouch *touch in ended) {
                [tap->touches removeObject:[touch identity]];
            }
            
            tap->fingers=[tap->touches count];
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

            NSLog(@"pid %@ cont %@ dy %@ dx %@ wDevice %@ wMouse %@ fingers %@ sampled %@ source %@ invert %@",
                  @(pid), @(continuous), @(pixel_axis1), @(pixel_axis2), @(wacomDevice), @(wacomMouse), @(tap->fingers), @(tap->sampledFingers), @(source), @(invert));

        }
        else if(type==kCGEventTapDisabledByTimeout)
        {
            // This can happen sometimes. (Not sure why.) 
            [tap enableTap:TRUE]; // Just re-enable it.
        }	
        
		return event;
	}
}

@implementation MouseTap

- (BOOL)isActive
{
	return source&&port;
}

- (void)start
{
	if([self isActive])
		return;

    // initialise
    _preventReverseOtherApp=[[NSUserDefaults standardUserDefaults] boolForKey:@"ReverseOnlyRawInput"];
    _detectWacomMouse=![[NSUserDefaults standardUserDefaults] boolForKey:@"DisableWacomMouseDetection"];
    touches=[NSMutableSet set];

	// create mach port
	port=(CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
										   kCGTailAppendEventTap,
										   kCGEventTapOptionDefault,
										   CGEventMaskBit(kCGEventScrollWheel)|CGEventMaskBit(kCGEventTabletProximity)|NSEventMaskGesture,
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
