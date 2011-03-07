//
//  MouseTap.m
//
//  Created by Nicholas Moore on 03/03/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "MouseTap.h"

// This is called every time there is a scroll event. It has to be efficient.
static CGEventRef eventTapCallback (CGEventTapProxy proxy,
							 CGEventType type,
							 CGEventRef event,
							 void *userInfo)
{
	MouseTap *tap=(MouseTap *)userInfo;
	if (tap->inverting) {
		if (type==kCGEventScrollWheel) {
			// line deltas
			int64_t ldy=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);		
			int64_t ldx=CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
			NSLog(@"ldx: %lli, ldy: %lli", ldx, ldy);
			
			// pixel deltas
			int64_t dy=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);				
			int64_t dx=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
			NSLog(@"dx: %lli, dy: %lli", dx, dy);
			
			/* Negate them all. It's worth noting we have to set them in this order (lines then pixels) 
			 otherwise the line setting clobbers the pixel setting and scrolling stops being smooth. */
			CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, -ldy);		
			CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, -ldx);
			CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -dy);		
			CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, -dx);
		}
		else  {
			// something else, probably error
			NSLog(@"*********** unexpected tap event type: %d ", type);
			if(type==kCGEventTapDisabledByTimeout) { 
				// this can happen sometimes (why? dunno...) 
				[tap enableTap:TRUE]; // just re-enable it
			}	
		}		
	}
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
