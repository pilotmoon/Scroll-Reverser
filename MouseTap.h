// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Foundation/Foundation.h>

// The possible sources of scrolling events.
typedef enum {
    ScrollEventSourceMouse=0,
    ScrollEventSourceTrackpad,
    ScrollEventSourceTablet,
    ScrollEventSourceMax 
} ScrollEventSource;

// We abstract the system defined scrolling phases into these possibilities.
typedef enum {
    ScrollPhaseStart=0,
    ScrollPhaseNormal, // fingers on pad
    ScrollPhaseMomentum, // fingers off pad, but scrolling with momentum
    ScrollPhaseEnd,      // scrolling ended
    ScrollPhaseMax
} ScrollPhase;

@class MouseTap, TapLogger;
@interface MouseTap : NSObject {
	CFMachPortRef activeTapPort;
	CFRunLoopSourceRef activeTapSource;
    CFMachPortRef passiveTapPort;
    CFRunLoopSourceRef passiveTapSource;

@public
    NSUInteger touching;
    uint64_t lastTouchTime;
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
- (void)enableTap;
- (void)resetTap;

@end


