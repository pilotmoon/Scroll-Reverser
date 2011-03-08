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
	id pointObj;
	SEL pointSel;
}

- (void)setView:(NSView *)view;
- (void)setPointObj:(id)obj sel:(SEL)pointSel;

@property (readwrite, copy) NSPoint (^centerBlock)(void);
@end
