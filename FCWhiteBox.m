//
//  FCWhiteBox.m
//  fc
//
//  Created by Work on 25/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "FCWhiteBox.h"


@implementation FCWhiteBox

-(void)drawRect:(NSRect)dirtyRect
{

	NSRect windowRect=[self bounds];
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:windowRect xRadius:12.0 yRadius:12.0];
	
	// clear rect
	//[[NSColor whiteColor] set];
	//NSRectFill(windowRect);
	
	// fill background	
	NSColor *startColor  = [NSColor colorWithDeviceWhite:0.95 alpha:1.0];
	NSColor *endColor    = [NSColor colorWithDeviceWhite:1.000 alpha:1.0];
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:startColor, 0.0, endColor, 1.0, nil];
	[[gradient autorelease] drawInBezierPath:path angle:90];
	
	// draw edge
	/*[NSGraphicsContext saveGraphicsState];
	[[[NSColor blackColor] colorWithAlphaComponent:0.1] set];
	[path setLineWidth:2.0];
	[path addClip];
	[path stroke];
	[NSGraphicsContext restoreGraphicsState];*/
}

@end
