//
//  FCImageButton.m
//  fc
//
//  Created by Work on 15/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "FCImageButton.h"
#import "FCImageButtonCell.h"

@implementation FCImageButton
@synthesize mouseIn;

+ (Class)cellClass
{
	return [FCImageButtonCell class];
}

- (void)setImage:(NSImage *)image
{
	[[self cell] setImage:image];
}

- (void)setAlternateImage:(NSImage *)image
{
	[[self cell] setAlternateImage:image];
}

- (void)addTracking
{
	[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:[self bounds]
													   options:NSTrackingActiveAlways|NSTrackingMouseEnteredAndExited
														 owner:self
													  userInfo:0]];
}

- (id)initWithFrame:(NSRect)frameRect
{
	self=[super initWithFrame:frameRect];
	if (self) {
		[self addTracking];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self=[super initWithCoder:aDecoder];
	[self addTracking];
	return self;
}

- (void)mouseEntered:(NSEvent *)event
{
	mouseIn=YES;
	[self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event
{
	mouseIn=NO;
	[self setNeedsDisplay:YES];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
	mouseIn=NO;
	[self setNeedsDisplay:YES];
}

@end
