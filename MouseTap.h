#import <Foundation/Foundation.h>

typedef enum {
    ScrollEventSourceMouse=0,
    ScrollEventSourceTrackpad,
    ScrollEventSourceTablet,
    ScrollEventSourceMax 
} ScrollEventSource;

/*
 We abstract the system defined scrolling phases into these possibilities.
 */
typedef enum {
    ScrollPhaseStart=0, // fingers on pad
    ScrollPhaseNormal, // fingers on pad
    ScrollPhaseMomentum, // fingers off pad, but scrolling with momentum
    ScrollPhaseEnd,       // scrolling ended
    ScrollPhaseMax
} ScrollPhase;

@class MouseTap, TapLogger;
@interface MouseTap : NSObject {
	CFMachPortRef activeTapPort;
	CFRunLoopSourceRef activeTapSource;
    CFMachPortRef passiveTapPort;
    CFRunLoopSourceRef passiveTapSource;

@public
    uint64_t lastEventTime;
    uint64_t lastSeenFingersTime;
    uint64_t lastSeenFingers;

    CGEventType lastEventType;
    ScrollPhase lastPhase;
    ScrollEventSource lastSource;
    
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
- (void)enableTaps;
- (void)resetState;
@end


