//
//  MouseTap.h
//
//  Created by Nicholas Moore on 03/03/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MouseTap;
struct MouseTapData {
	MouseTap *tap;
	BOOL invert;
};

@interface MouseTap : NSObject {
	CGEventMask mask;
	CFMachPortRef port;
	CFRunLoopSourceRef source;
	struct MouseTapData data;
}
@property (assign, getter=isActive) BOOL active;
- (void)start;
- (void)stop;
- (void)enableTap:(BOOL)state;
@end


