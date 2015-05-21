#import <Foundation/Foundation.h>

typedef enum {
    ScrollEventSourceOther=0,  
    ScrollEventSourceTrackpad,
    ScrollEventSourceTablet,
    ScrollEventSourceMax 
} ScrollEventSource;

/*
 We abstract the system defined scrolling phases into these possibilities.
 */
typedef enum {
    ScrollPhaseNormal=0, // fingers on pad
    ScrollPhaseMomentum, // fingers off pad, but scrolling with momentum
    ScrollPhaseEnd,       // scrolling ended
    ScrollPhaseMax
} ScrollPhase;

@class MouseTap, TapLogger;
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
    unsigned long rawZeroCount;
    unsigned long zeroCount;
    UInt32 lastScrollTicks;
    unsigned long lastPhase;
	BOOL inverting;
    BOOL invertX;
    BOOL invertY;
    BOOL invertMultiTouch;
    BOOL invertTablet;
    BOOL invertOther;
    __weak TapLogger *logger;
}
- (void)start;
- (void)stop;
- (void)enableTap:(BOOL)state;
- (void)resetState;
@end


