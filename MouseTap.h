#import <Foundation/Foundation.h>

typedef enum {
    ScrollEventSourceOther=0,  
    ScrollEventSourceTrackpad,
    ScrollEventSourceTablet,
    ScrollEventSourceMax 
} ScrollEventSource;

@class MouseTap;
@interface MouseTap : NSObject {
	CGEventMask mask;
	CFMachPortRef port;
	CFRunLoopSourceRef source;
@public
	/* This is public so that the tap function doesn't have to invoke a method to get to it.
	 Maybe over-optimizing here but it's all pretty straightforward. */
    NSMutableSet *touches;
    unsigned long fingers;
    unsigned long sampledFingers;
    unsigned long zeroCount;
    UInt32 lastScrollTicks;
    unsigned long lastPhase;
	BOOL inverting;
    BOOL invertX;
    BOOL invertY;
    BOOL invertMultiTouch;
    BOOL invertTablet;
    BOOL invertOther;
}
- (void)start;
- (void)stop;
- (void)enableTap:(BOOL)state;
@end


