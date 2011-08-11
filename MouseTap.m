#import "MouseTap.h"

#define NEGATE_FIELD (type) CGEventSetIntegerValueField(event, type, -CGEventGetIntegerValueField(event, type))
#define MAGIC_NUMBER (0x7363726F726576)
// "scrorev" in hex

// This is called every time there is a scroll event. It has to be efficient.
static CGEventRef eventTapCallback (CGEventTapProxy proxy,
							 CGEventType type,
							 CGEventRef event,
							 void *userInfo)
{
	MouseTap *tap=(MouseTap *)userInfo;
	if (tap->inverting)
	{
		if (type==kCGEventScrollWheel)
		{
			// don't reverse scrolling we have already reversed
			int64_t ud=CGEventGetIntegerValueField(event, kCGEventSourceUserData);
			if (ud==MAGIC_NUMBER) {
				goto end_tap;
			}
            
			// First get the line and pixel delta values.
            int64_t line_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
            int64_t line_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
            double fixedpt_axis1 = CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
            double fixedpt_axis2 = CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);
            int64_t pixel_axis1=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
            int64_t pixel_axis2=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
			
			/* Now negate them all. It's worth noting we have to set them in this order (lines then pixels) 
			 or we lose smooth scrolling. */
			CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, -line_axis1);		
			CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, -line_axis2);
            CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, -1 * fixedpt_axis1);
            CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, -1 * fixedpt_axis2);
			CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -pixel_axis1);		
			CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, -pixel_axis2);
			
			// set user data
			CGEventSetIntegerValueField(event, kCGEventSourceUserData, MAGIC_NUMBER);									
		}
		else 
		{
			if(type==kCGEventTapDisabledByTimeout)
			{ 
				// This can happen sometimes. (Not sure why.) 
				[tap enableTap:TRUE]; // Just re-enable it.
			}	
		}		
	}
end_tap:
	return event;
}

@implementation MouseTap
@synthesize inverting;

- (BOOL)isActive
{
	return source&&port;
}

- (void)start
{
	if(self.active)
		return;

	// create mach port
	port = (CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
										   kCGTailAppendEventTap,
										   kCGEventTapOptionDefault,
										   CGEventMaskBit(kCGEventScrollWheel),
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
