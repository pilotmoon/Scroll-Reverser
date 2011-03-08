//
//  DCStatusItemView.m
//  dc
//
//  Created by Work on 20/12/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "DCStatusItemView.h"
#import "DCStatusItemController.h"

@implementation DCStatusItemView

- (id)initWithFrame:(NSRect)frame controller:(DCStatusItemController *)aController
{
	if([super initWithFrame:frame])
	{
		controller=aController;	
		[self addTrackingArea:[[NSTrackingArea alloc] initWithRect:[self frame]
														   options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
															 owner:controller
														  userInfo:nil]];
	}
	return self;
}

- (BOOL)isFlipped
{
	return NO;
}

- (void)drawRect:(NSRect)rect
{
	[controller.statusItem drawStatusBarBackgroundInRect:rect withHighlight:controller.menuIsOpen];
    [[self image] drawAtPoint:NSMakePoint(2, 3) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];	
}

- (void)mouseDown:(NSEvent *)event
{
	[controller showAttachedMenu:YES];
	[self setNeedsDisplay:YES];
}




@end
