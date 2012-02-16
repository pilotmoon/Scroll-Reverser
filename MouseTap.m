#import "MouseTap.h"
#import "CoreFoundation/CoreFoundation.h"

#ifdef TIGER_BUILD
extern CFRunLoopRef CFRunLoopGetMain(void);
#endif

#define MAGIC_NUMBER (0x7363726F726576) // "scrorev" in hex

static BOOL _preventReverseOtherApp;

/*
 Get the bundle identifier for the given pid.
 */
static NSString *_bundleIdForPID(const pid_t pid)
{
	ProcessSerialNumber psn={0, 0};
	OSStatus status=GetProcessForPID(pid, &psn);
	if (status==noErr)
	{
        NSDictionary * dict=[(NSDictionary *)ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask) autorelease];
		return [dict objectForKey:(NSString *)kCFBundleIdentifierKey];
	}
	return nil;
}


/*
 Is the pid a wacom tablet?
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
 Work out the scrolling phase (work on 10.6 and 10.7)
 */
typedef enum {
    ScrollPhaseNormal=0,
    ScrollPhaseMomentum,
    ScrollPhaseEnd
} ScrollPhase;

static ScrollPhase _MomentumPhaseForEvent(CGEventRef event)
{
    ScrollPhase result=ScrollPhaseNormal;
#ifndef TIGER_BUILD		
    NSEvent *ev=[NSEvent eventWithCGEvent:event];
    NSUInteger momentumPhase=0;
    NSUInteger scrollPhase=0;		
    if ([ev respondsToSelector:@selector(momentumPhase)]) { // 10.7
        momentumPhase=(NSUInteger)[ev performSelector:@selector(momentumPhase)];
    }
    if ([ev respondsToSelector:@selector(_scrollPhase)]) { // 10.6 (private method)
        scrollPhase=(NSUInteger)[ev performSelector:@selector(_scrollPhase)];
    }		
    if (momentumPhase==4||scrollPhase==2) {
        result=ScrollPhaseMomentum;
    }
    else if (momentumPhase==8||scrollPhase==3) {
        result=ScrollPhaseEnd;
    }
#endif
    return result;
}


static void _DoReversal(MouseTap *tap, CGEventRef event)
{
    // First get the line and pixel delta values.
    int64_t line_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    int64_t line_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
#ifndef TIGER_BUILD
    double fixedpt_axis1=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
    double fixedpt_axis2=CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);
    int64_t pixel_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    int64_t pixel_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
#endif
    /* Now negate them all. It's worth noting we have to set them in this order (lines then pixels) 
     or we lose smooth scrolling. */
    if (tap->invertY) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, -line_axis1);	
    if (tap->invertX) CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, -line_axis2);
#ifndef TIGER_BUILD
    if (tap->invertY) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, -1 * fixedpt_axis1);
    if (tap->invertX) CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, -1 * fixedpt_axis2);
    if (tap->invertY) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -pixel_axis1);		
    if (tap->invertX) CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, -pixel_axis2);
#endif
    // set user data
    CGEventSetIntegerValueField(event, kCGEventSourceUserData, MAGIC_NUMBER);		
}

// This is called every time there is a scroll event. It has to be efficient.
static CGEventRef eventTapCallback(CGEventTapProxy proxy,
							 CGEventType type,
							 CGEventRef event,
							 void *userInfo)
{    
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	MouseTap *tap=(MouseTap *)userInfo;
    
    if (type==NSEventTypeGesture)
    {
#ifndef TIGER_BUILD    
        // how many fingers on the pad
        NSEvent *ev=[NSEvent eventWithCGEvent:event];
        tap->fingers=[[ev touchesMatchingPhase:NSTouchPhaseTouching inView:nil] count];		
        NSLog(@"fingers %lu", tap->fingers);
#endif
    }
    else if (type==kCGEventScrollWheel)
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
            const ScrollPhase phase=_MomentumPhaseForEvent(event);        
            const UInt32 ticks=TickCount(); // about 1/60 of a sec
            const UInt32 ticksElapsed=ticks-tap->lastScrollTicks;

            NSLog(@"scroll %i", phase);
            
            if (phase==ScrollPhaseNormal&&(tap->lastPhase!=ScrollPhaseNormal||tap->sampledFingers==0||tap->zeroCount>2||ticksElapsed>20))
            {
                tap->sampledFingers=tap->fingers;
                NSLog(@"Sampled %lu fingers", tap->sampledFingers);
            }
             
            if (tap->fingers>0) {
                tap->zeroCount=0;
            }
            else {
                tap->zeroCount+=1;
            }

            tap->lastPhase=phase;     
            tap->lastScrollTicks=TickCount();
            
            if (tap->sampledFingers>0)
            {
                source=ScrollEventSourceTrackpad;
            }
        }
        
        NSLog(@"source %i", source);        
        
        
        // don't reverse scrolling we have already reversed
        const int64_t ud=CGEventGetIntegerValueField(event, kCGEventSourceUserData);
        const BOOL preventBecauseOfMagicNumber=ud==MAGIC_NUMBER;
        
        // don't reverse scrolling which comes from another app (if that setting is on)
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
                _DoReversal(tap, event);
            }
        }
    }
    else if(type==kCGEventTapDisabledByTimeout)
    { 
        // This can happen sometimes. (Not sure why.) 
        [tap enableTap:TRUE]; // Just re-enable it.
    }	
    
    [pool drain];
	return event;
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

#ifndef TIGER_BUILD
    // should we hook gesture events
    const BOOL touchAvailable=[NSEvent instancesRespondToSelector:@selector(touchesMatchingPhase:inView:)];
    const CGEventMask touchMask=touchAvailable?NSEventMaskGesture:0;
#else
	const CGEventMask touchMask=0;
#endif
	// create mach port
	port = (CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
										   kCGTailAppendEventTap,
										   0, //kCGEventTapOptionDefault
										   CGEventMaskBit(kCGEventScrollWheel)|CGEventMaskBit(kCGEventTabletProximity)|touchMask,
										   eventTapCallback,
										   self);

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
