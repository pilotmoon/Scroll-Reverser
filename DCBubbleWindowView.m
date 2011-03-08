//
//  DCBubbleWindowView.m
//  dc
//
//  Created by Work on 17/01/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "DCBubbleWindowView.h"
#import "DCNubWindow.h"

@implementation DCBubbleWindowView

//
// drawRect:
//
// Draws the frame of the window.
//
- (void)drawRect:(NSRect)rect
{
	NSLog(@"DRAW!!!");
	NSBezierPath *path = [[self ownerWindow] nubWindowPath];
	
	// the window rect
	NSRect windowRect=[self bounds];
	
	// clear rect
	[[NSColor clearColor] set];
	NSRectFill(windowRect);
	
	// fill background	
	NSColor *startColor  = [NSColor colorWithDeviceWhite:0.871 alpha:1.0];
	NSColor *endColor    = [NSColor colorWithDeviceWhite:1.000 alpha:1.0];
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:startColor, 0.0, endColor, 1.0, nil];
	[[gradient autorelease] drawInBezierPath:path angle:90];
	
	// draw edge
	[NSGraphicsContext saveGraphicsState];
	[[[NSColor whiteColor] colorWithAlphaComponent:0.5] set];
	[path setLineWidth:2.0];
	[path addClip];
	[path stroke];
	[NSGraphicsContext restoreGraphicsState];
}

@end
