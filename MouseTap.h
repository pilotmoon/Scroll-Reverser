#import <Foundation/Foundation.h>

@class MouseTap;
@interface MouseTap : NSObject {
	CGEventMask mask;
	CFMachPortRef port;
	CFRunLoopSourceRef source;
@public
	/* This is public so that the tap function doesn't have to invoke a method to get to it.
	 Maybe over-optimizing here but it's all pretty straightforward. */
    BOOL tabletProx;
    NSUInteger fingers;
    BOOL cachedIsTrackpad;
    UInt32 lastScrollEventTick;
	BOOL inverting;
    BOOL invertX;
    BOOL invertY;
    BOOL invertMultiTouch;
    BOOL invertTablet;
    BOOL invertOther;
}
@property (readonly, getter=isActive) BOOL active;
@property (getter=isInverting) BOOL inverting;
@property (getter=isInvertX) BOOL invertX;
@property (getter=isInvertY) BOOL invertY;
@property (getter=isInvertMultiTouch) BOOL invertMultiTouch;
@property (getter=isInvertTablet) BOOL invertTablet;
@property (getter=isInvertOther) BOOL invertOther;
- (void)start;
- (void)stop;
- (void)enableTap:(BOOL)state;
@end


