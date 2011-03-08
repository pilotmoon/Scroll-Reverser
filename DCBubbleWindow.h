//
//  DCBubbleWindow.h
//  dc
//
//  Created by Work on 17/01/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DCNubWindow.h"

@class DCBubbleWindowView;

@interface DCBubbleWindow : DCNubWindow {
	NSView *childContentView;
	NSWindow *attachedWindow;
	NSPoint(^centerBlock)(void);
}

- (void)setView:(NSView *)view;

@property (readwrite, copy) NSPoint (^centerBlock)(void);
@end
