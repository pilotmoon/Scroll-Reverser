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
    BOOL tabletProx;
    BOOL tabletProxOverride;
    BOOL lastTabletProxOverride;
    unsigned long fingers;
    BOOL cachedIsTrackpad;
    UInt32 lastScrollEventTick;
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


