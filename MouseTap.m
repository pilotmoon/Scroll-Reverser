#import "MouseTap.h"

#define NEGATE_FIELD (type) CGEventSetIntegerValueField(event, type, -CGEventGetIntegerValueField(event, type))
#define MAGIC_NUMBER (0x7363726F726576)
// "scrorev" in hex


static NSString *_bundleIdForPID(const pid_t pid)
{
	ProcessSerialNumber psn={0, 0};
	OSStatus status=GetProcessForPID(pid, &psn);
	if (status==noErr)
	{
		return [(NSDictionary *)NSMakeCollectable(ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask)) objectForKey:(NSString *)kCFBundleIdentifierKey];
	}
	return nil;
}

static BOOL _pidIsTablet(const pid_t pid)
{
    static pid_t lastKnownTabletPid=0;
    
    // check last know value (faster)
    if (pid==lastKnownTabletPid)
    {
        NSLog(@"lastknown");
        return YES;
    }
    
    // look it up
    const BOOL pidIsTablet=[[_bundleIdForPID(pid) lowercaseString] rangeOfString:@"wacom"].length>0;
    if (pidIsTablet)
    {
        lastKnownTabletPid=pid;
        return YES;
    }
    
    return NO;
}

// This is called every time there is a scroll event. It has to be efficient.
static CGEventRef eventTapCallback (CGEventTapProxy proxy,
							 CGEventType type,
							 CGEventRef event,
							 void *userInfo)
{    
	MouseTap *tap=(MouseTap *)userInfo;
    BOOL tabletProxChanged=NO;
    
    if (type==kCGEventTabletProximity) 
    {
        // is the pen next to the tablet?
        tap->tabletProx=!!CGEventGetIntegerValueField(event, kCGTabletProximityEventEnterProximity);
    }
    else if (type==NSEventTypeGesture)
    {
        // how many fingers on the pad
        tap->fingers=[[[NSEvent eventWithCGEvent:event] touchesMatchingPhase:NSTouchPhaseTouching inView:nil] count];		
    }
    else if (type==kCGEventScrollWheel)
    {
        // check for tablet override
        const uint64_t pid=CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
        tap->tabletProxOverride=pid&&_pidIsTablet(pid);
            
        // override
        if(tap->tabletProxOverride)
        {
            tap->tabletProx=YES;
        }            
        
        // has proximity changed
        tabletProxChanged=(tap->lastTabletProxOverride!=tap->tabletProxOverride);
        tap->lastTabletProxOverride=tap->tabletProxOverride;
        
        NSLog(@"tabletprox changed? %d", tabletProxChanged);
        
        // cached trackpad state so we invert the momentum
        const UInt32 tickCount=TickCount();
        const UInt32 ticksElapsed=tickCount-tap->lastScrollEventTick;
        tap->lastScrollEventTick=tickCount;
        const BOOL newScrollEvent=tabletProxChanged||ticksElapsed>20; // ticks are about 1/60 of second
        if (newScrollEvent) 
        {
            tap->cachedIsTrackpad=tap->fingers>0;
        }
        
        // determine source
        ScrollEventSource source=ScrollEventSourceOther;
        if (tap->cachedIsTrackpad)
        {
            source=ScrollEventSourceTrackpad;
        }
        else if (tap->tabletProx)
        {
            source=ScrollEventSourceTablet;
        }
        
        // don't reverse scrolling we have already reversed
        const int64_t ud=CGEventGetIntegerValueField(event, kCGEventSourceUserData);
        if (ud!=MAGIC_NUMBER)
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
                double fixedpt_axis1 = CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
                double fixedpt_axis2 = CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);
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
        }
    }
    else if(type==kCGEventTapDisabledByTimeout)
    { 
        // This can happen sometimes. (Not sure why.) 
        [tap enableTap:TRUE]; // Just re-enable it.
    }	
    
	return event;
}

@implementation MouseTap
@synthesize inverting, invertX, invertY, invertMultiTouch, invertOther, invertTablet;

- (BOOL)isActive
{
	return source&&port;
}

- (void)start
{
	if(self.active)
		return;

    // should we hook gesture events
    const BOOL touchAvailable=[NSEvent instancesRespondToSelector:@selector(touchesMatchingPhase:inView:)];
    const CGEventMask touchMask=touchAvailable?NSEventMaskGesture:0;
    
	// create mach port
	port = (CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
										   kCGTailAppendEventTap,
										   kCGEventTapOptionDefault,
										   CGEventMaskBit(kCGEventScrollWheel)|CGEventMaskBit(kCGEventTabletProximity)|touchMask,
										   eventTapCallback,
										   self);

	// create source and add to tun loop
	source = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0);
	CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
}

- (void)stop
{
	if (!self.active)
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
