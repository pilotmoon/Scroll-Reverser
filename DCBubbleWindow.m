//
//  DCBubbleWindow.m
//  dc
//
//  Created by Work on 17/01/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "DCBubbleWindow.h"
#import "DCBubbleWindowView.h"

#define BUBBLE_NUB_SIZE 9.0

@implementation DCBubbleWindow
@synthesize centerBlock;

- (CGFloat)cornerRadius
{
	return 9.0;
}

- (id)initWithContentRect:(NSRect)contentRect
				styleMask:(NSUInteger)windowStyle
				  backing:(NSBackingStoreType)bufferingType
					defer:(BOOL)deferCreation
{
	self = [super initWithBoxSize:contentRect.size
					  nubLocation:NSZeroPoint
					  nubPosition:DCNubPositionTop
						  nubSize:BUBBLE_NUB_SIZE];
	if (self)
	{
		[self setLevel:NSMainMenuWindowLevel+1];
		[self setAvoidEdgeOverlap:NO];
		[self setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	}
	return self;
}



//
// setContentSize:
//
// Convert from childContentView to frameView for size.
//
- (void)setContentSize:(NSSize)newSize
{
	NSLog(@"Set Content Size: %@", NSStringFromSize(newSize));
	[self setBoxSize:newSize];
	
	[self drawNubWindow];
}

//
// setContentView:
//
// Keep our frame view as the content view and make the specified "aView"
// the child of that.
//
- (void)setContentView:(NSView *)aView
{
	NSLog(@"Set Content View: %@", aView);
	
	if ([childContentView isEqualTo:aView])
	{
		return;
	}
	
	NSRect bounds = [self frame];
	bounds.origin = NSZeroPoint;
	
	DCBubbleWindowView *frameView = [super contentView];
	if (!frameView)
	{
		frameView = [[[DCBubbleWindowView alloc] initWithFrame:bounds] autorelease];		
		[super setContentView:frameView];
	}
	
	if (childContentView)
	{
		[childContentView removeFromSuperview];
	}
	childContentView = aView;
	NSRect cvframe=[self contentRectForFrameRect:bounds];
	if (nubPosition==DCNubPositionLeft||nubPosition==DCNubPositionRight) {
		cvframe.origin.x+=nubSize;
	}
	[childContentView setFrame:cvframe];
	[childContentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[frameView addSubview:childContentView];
}

//
// contentView
//
// Returns the child of our frame view instead of our frame view.
//
- (NSView *)contentView
{
	return childContentView;
}

//
// contentRectForFrameRect:
//
// Returns the rect for the content rect, taking the frame.
//
- (NSRect)contentRectForFrameRect:(NSRect)windowFrame
{
	windowFrame.origin = NSZeroPoint;
	if (nubPosition==DCNubPositionTop||nubPosition==DCNubPositionBottom) {
		windowFrame.size.height-=BUBBLE_NUB_SIZE;
	}
	else {
		windowFrame.size.width-=BUBBLE_NUB_SIZE;
	}
	return windowFrame;
}

//
// frameRectForContentRect:styleMask:
//
// Ensure that the window is make the appropriate amount bigger than the content.
//
+ (NSRect)frameRectForContentRect:(NSRect)windowContentRect styleMask:(NSUInteger)windowStyle
{
	NSLog(@"getframerect");
	//if (nubPosition==DCNubPositionTop||nubPosition==DCNubPositionBottom) {
	//  windowContentRect.size.height+=BUBBLE_NUB_SIZE;
	//}
	//else {
	//	windowContentRect.size.width+=BUBBLE_NUB_SIZE;
	//}
	return windowContentRect;
}

- (void)center
{
	if (centerBlock) {
		NSLog(@"centerBlock");
		[self setNubLocation:centerBlock()];
	}
	else if (pointObj) {
		NSLog(@"centerBlock");
		NSValue *pt=(NSValue *)[pointObj performSelector:pointSel withObject:nil];
		[self setNubLocation:[pt pointValue]];
	}
	else {
		NSLog(@"center");
		[self setNubLocation:NSMakePoint(500, 500)];
		[super center];
	}

	[self drawNubWindow];
}

- (void)setView:(NSView *)view
{
	// TODO make this clean
	NSSize size=[view frame].size;
	[self setContentView:view];
	[self setContentSize:size];
}

- (BOOL)canBecomeKeyWindow
{
	return YES;
}

- (void)setPointObj:(id)obj sel:(SEL)sel
{
	pointObj=obj;
	pointSel=sel;
}

@end
