//
//  MouseTap.m
//
//  Created by Nicholas Moore on 03/03/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "MouseTap.h"

/* This is called every time there is a scroll event. It has to be efficient. */
static CGEventRef eventTapCallback (CGEventTapProxy proxy,
							 CGEventType type,
							 CGEventRef event,
							 void *refcon)
{
	struct MouseTapData *data=(struct MouseTapData *)refcon;
	if (data->invert) {
		if (type==kCGEventScrollWheel) {
			// negate the x and y scrolling deltas
			int64_t dx=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
			int64_t dy=CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);				
			NSLog(@"dx: %lli, dy: %lli", dx, dy);
			CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, -dx);
			CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -dy);		
		}
		else  {
			// something else, probably error
			NSLog(@"*********** unexpected tap event type: %d ", type);
			if(type==kCGEventTapDisabledByTimeout) { 
				// this can happen sometimes (why? dunno...) 
				[data->tap enableTap:TRUE]; // just re-enable it
			}	
		}		
	}
	return event;
}

@implementation MouseTap

#pragma mark Special tap enable

- (void)enableTap:(BOOL)state
{
	CGEventTapEnable(port, state);
}

#pragma mark Activation

- (void)start
{
	NSLog(@"tap start called");
	if(![self isActive]) {
		data.tap=self;
		data.invert=YES;
		
		[self willChangeValueForKey:@"active"];
		
		// create mach port
		port = (CFMachPortRef)CGEventTapCreate(kCGSessionEventTap,
											   kCGTailAppendEventTap,
											   kCGEventTapOptionDefault,
											   CGEventMaskBit(kCGEventScrollWheel),
											   eventTapCallback,
											   &data);
		NSCAssert(port!=NULL,nil);
		NSCAssert(CFMachPortIsValid(port),nil);
		
		// create source
		source = (CFRunLoopSourceRef)CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0);
		NSCAssert(source!=NULL,nil);
		
		// add source to run loop
		CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
		[self didChangeValueForKey:@"active"];
	}
}

- (void)stop
{
	if ([self isActive]) {
		[self willChangeValueForKey:@"active"];
		CFRunLoopRemoveSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
		CFMachPortInvalidate(port);
		CFRelease(source);
		CFRelease(port);
		[self didChangeValueForKey:@"active"];		
	}
}

- (void)setActive:(BOOL)state
{
	state?[self start]:[self stop];
}

- (BOOL)isActive
{
	return source&&port;
}

@end
