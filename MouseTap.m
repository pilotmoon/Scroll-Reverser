#import "MouseTap.h"
#import "CoreFoundation/CoreFoundation.h"

#ifdef TIGER_BUILD
extern CFRunLoopRef CFRunLoopGetMain(void);
#endif

#define MAGIC_NUMBER (0x7363726F726576) // "scrorev" in hex

static BOOL _preventReverseOtherApp;
static BOOL _wacomMode=NO;

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

static BOOL _pidIsTablet(const pid_t pid)
{
    static pid_t lastKnownTabletPid=0;
    
    // check last know value (faster)
    if (pid==lastKnownTabletPid)
    {
        return YES;
    }
    
    // look it up
    NSString *bid=[_bundleIdForPID(pid) lowercaseString];
    NSLog(@"bid %@", bid);
    const BOOL pidIsTablet=[bid rangeOfString:@"wacom"].length>0;
    if (pidIsTablet)
    {
        lastKnownTabletPid=pid;
        _wacomMode=YES;
        return YES;
    }
    
    return NO;
}

// This is called every time there is a scroll event. It has to be efficient.
static CGEventRef eventTapCallback(CGEventTapProxy proxy,
							 CGEventType type,
							 CGEventRef event,
							 void *userInfo)
{    
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	MouseTap *tap=(MouseTap *)userInfo;
    
    if (type==kCGEventTabletProximity) 
    {
        NSEvent *ev=[NSEvent eventWithCGEvent:event];
        NSLog(@"event %@", ev);
        // is the pen next to the tablet?
        if(_wacomMode) 
        {
            tap->tabletProx=NO;           
        }
        else
        {
            tap->tabletProx=!!CGEventGetIntegerValueField(event, kCGTabletProximityEventEnterProximity);   
        }
    }
#ifndef TIGER_BUILD
    else if (type==NSEventTypeGesture)
    {
        // how many fingers on the pad
        NSEvent *ev=[NSEvent eventWithCGEvent:event];
        NSLog(@"event %@", ev);
        tap->fingers=[[ev touchesMatchingPhase:NSTouchPhaseTouching inView:nil] count];		
        NSLog(@"fingers %lu", tap->fingers);
    }
#endif
    else if (type==kCGEventScrollWheel)
    {
        NSEvent *ev=[NSEvent eventWithCGEvent:event];
        NSLog(@"event %@", ev);
        NSLog(@"scroll"); // check for tablet override
        const uint64_t pid=CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
        tap->tabletProxOverride=pid&&_pidIsTablet(pid);
        if (tap->tabletProxOverride) {
            tap->fingers=0;
        }
        
        // has proximity changed
        const BOOL tabletProxOverrideChanged=(tap->lastTabletProxOverride!=tap->tabletProxOverride);
        tap->lastTabletProxOverride=tap->tabletProxOverride;
        
        // cached trackpad state so we invert the momentum
        const UInt32 tickCount=TickCount();
        const UInt32 ticksElapsed=tickCount-tap->lastScrollEventTick;
        tap->lastScrollEventTick=tickCount;
        const BOOL newScrollEvent=tabletProxOverrideChanged||ticksElapsed>20; // ticks are about 1/60 of second
        NSLog(@"ticks %u", ticksElapsed);
        if (newScrollEvent) 
        {
            NSLog(@"newscrollevent fingers %lu", tap->fingers);
            tap->cachedIsTrackpad=tap->fingers>0;
        }
        
        
        NSLog(@"cachedt %d prox %d proxover %d", tap->cachedIsTrackpad, tap->tabletProx, tap->tabletProxOverride);
        
        // determine source
        ScrollEventSource source=ScrollEventSourceOther;
        if (tap->cachedIsTrackpad)
        {
            source=ScrollEventSourceTrackpad;
        }
        else if (tap->tabletProxOverride||tap->tabletProx)
        {
            source=ScrollEventSourceTablet;
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
            if (sourcepid!=0) {
                preventBecauseComingFromOtherApp=YES;
            }
        }
        
        if (tap->inverting&&!(preventBecauseOfMagicNumber||preventBecauseComingFromOtherApp))
        {
            
            BOOL allow=YES;
            switch (source)
            {
                case ScrollEventSourceTrackpad:
                    allow=tap->invertMultiTouch;
                    break;
                    
                case ScrollEventSourceTablet:
                    allow=tap->invertTablet;
                    break;
                    
                case ScrollEventSourceOther:
                default:
                    allow=tap->invertOther;
                    break;
            }
            if (allow) // now reverse the scrolling
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
