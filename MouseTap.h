#import <Foundation/Foundation.h>

@class MouseTap;
@interface MouseTap : NSObject {
	CGEventMask mask;
	CFMachPortRef port;
	CFRunLoopSourceRef source;
@public
	/* This is public so that the tap function doesn't have to invoke a method to get to it.
	 Maybe over-optimizing here but it's all pretty straightforward. */
	BOOL inverting;
}
@property (readonly, getter=isActive) BOOL active;
@property (getter=isInverting) BOOL inverting;
- (void)start;
- (void)stop;
- (void)enableTap:(BOOL)state;
@end


