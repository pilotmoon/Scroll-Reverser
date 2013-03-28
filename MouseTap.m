#import "MouseTap.h"
#import "CoreFoundation/CoreFoundation.h"

#define MAGIC_NUMBER (0x7363726F726576) // "scrorev" in hex

static BOOL _preventReverseOtherApp;
static unsigned long _minZeros;
static unsigned long _minFingers;

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
    NSLog(@"Tablet BID %@", bid);
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


static void _doReversal(MouseTap *tap, CGEventRef event)
{
    // First get the line and pixel delta values.
    int64_t line_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    int64_t line_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    double fixedpt_axis1=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
    double fixedpt_axis2=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);
    int64_t pixel_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    int64_t pixel_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);

    /* Now negate them all. It's worth noting we have to set them in this order (lines then pixels) 
     or we lose smooth scrolling. */
    if (tap->invertY) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, -line_axis1);	
    if (tap->invertX) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, -line_axis2);
    if (tap->invertY) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, -1 * fixedpt_axis1);
    if (tap->invertX) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, -1 * fixedpt_axis2);
    if (tap->invertY) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -pixel_axis1);		
    if (tap->invertX) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, -pixel_axis2);

    // set user data
    CGEventSetIntegerValueField(event, kCGEventSourceUserData, MAGIC_NUMBER);		
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
            // how many fingers on the trackpad?
            NSEvent *ev=[NSEvent eventWithCGEvent:event];
            tap->fingers=[[ev touchesMatchingPhase:NSTouchPhaseTouching inView:nil] count];
            //NSLog(@"fingers %lu", tap->fingers);
        }
        else if (type==NSScrollWheel)
        {
            // determine source
            ScrollEventSource source=ScrollEventSourceOther;
            
            // check if tablet
            const uint64_t pid=CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
            if (pid&&_pidIsWacomTablet(pid))
            {
                source=ScrollEventSourceTablet;
            }
            else
            {
                // make a pretty bold assumption here:
                // trackpad events are continuous and pixel-based
                // whereas mouse scroll events are discontinuous and line-based
                const uint64_t scrollEventIsContinuous = CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
                if(scrollEventIsContinuous) {
                    source=ScrollEventSourceTrackpad;
                }
            }
            
            //NSLog(@"source %i", source);
            
            // don't reverse scrolling we have already reversed
            const int64_t ud=CGEventGetIntegerValueField(event, kCGEventSourceUserData);
            const BOOL preventBecauseOfMagicNumber=ud==MAGIC_NUMBER;
            
            // don't reverse scrolling which comes from another app (if that setting is on)
            // this is useful Scroll Reverser running inside a remote desktop, to ignore scrolling coming from
            // the controlling host but still reverse local scrolling.
            BOOL preventBecauseComingFromOtherApp=NO;
            if(_preventReverseOtherApp)
            {
                int64_t sourcepid=CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
                if (sourcepid!=0)
                {
                    preventBecauseComingFromOtherApp=YES;
                }
            }
            
            if (tap->inverting&&!(preventBecauseOfMagicNumber||preventBecauseComingFromOtherApp))
            {
                BOOL invert=YES;
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
                if (invert)
                {
                    _doReversal(tap, event);
                }
            }
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
    
    _preventReverseOtherApp=[[NSUserDefaults standardUserDefaults] boolForKey:@"ReverseOnlyRawInput"];
    _minZeros=[[NSUserDefaults standardUserDefaults] integerForKey:@"MinZeros"];
    _minFingers=[[NSUserDefaults standardUserDefaults] integerForKey:@"MinFingers"];
    
    // should we hook gesture events
    const BOOL touchAvailable=[NSEvent instancesRespondToSelector:@selector(touchesMatchingPhase:inView:)];
    const CGEventMask touchMask=touchAvailable?NSEventMaskGesture:0;

	// create mach port
	port = (CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
										   kCGTailAppendEventTap,
										   kCGEventTapOptionDefault,
										   CGEventMaskBit(kCGEventScrollWheel)|CGEventMaskBit(kCGEventTabletProximity)|touchMask,
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
}

- (void)enableTap:(BOOL)state
{
	CGEventTapEnable(port, state);
}

@end
