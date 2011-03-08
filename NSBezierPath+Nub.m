//
//  NSBezierPath+Nub.m
//  WindowTest
//
//  Created by Work on 12/11/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "NSBezierPath+Nub.h"


@implementation NSBezierPath (Nub)

+ (NSBezierPath *)bezierPathWithNubRect:(NSRect)containingRect
								 radius:(CGFloat)radius
							nubPosition:(DCNubPosition)nubPosition
								nubSize:(CGFloat)nubSize
							  nubOffset:(CGFloat)nubOffset
{	
	// pre-rotate
	if (nubPosition==DCNubPositionRight||nubPosition==DCNubPositionLeft) {
		CGFloat h=containingRect.size.height;
		containingRect.size.height=containingRect.size.width;
		containingRect.size.width=h;
	}

	// make the inner rectangle
	NSRect rect=containingRect;
	rect.origin.y+=nubSize;
	rect.size.height-=nubSize;
	
	// the various points
	NSPoint topLeft = NSMakePoint( rect.origin.x, rect.origin.y );
	NSPoint nubStart = NSMakePoint( rect.origin.x + nubOffset - nubSize, rect.origin.y );
	NSPoint nubEnd = NSMakePoint( rect.origin.x + nubOffset + nubSize, rect.origin.y );
	NSPoint nubPoint = NSMakePoint( rect.origin.x + nubOffset, rect.origin.y - nubSize );
	NSPoint topRight = NSMakePoint( topLeft.x + rect.size.width, topLeft.y );
	NSPoint bottomRight = NSMakePoint( topRight.x, topRight.y + rect.size.height);
	NSPoint bottomLeft = NSMakePoint( topLeft.x, bottomRight.y );
	NSPoint startPoint = NSMakePoint( topLeft.x + radius, topLeft.y );	
	
	// build a path!
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:startPoint];	
	[path lineToPoint:nubStart];	
	[path lineToPoint:nubPoint];						   
	[path lineToPoint:nubEnd];		
	[path appendBezierPathWithArcFromPoint:topRight toPoint:bottomRight radius:radius];
	[path appendBezierPathWithArcFromPoint:bottomRight toPoint:bottomLeft radius:radius];
	[path appendBezierPathWithArcFromPoint:bottomLeft toPoint:topLeft radius:radius];
	[path appendBezierPathWithArcFromPoint:topLeft toPoint:startPoint radius:radius];
	[path closePath];

	// flip if nub is on top
	if (nubPosition==DCNubPositionTop||nubPosition==DCNubPositionRight) {
		NSAffineTransform *tx=[NSAffineTransform transform];
		[tx scaleXBy:1.0 yBy:-1.0];
		[tx translateXBy:0 yBy:nubSize-bottomRight.y-topRight.y];
		path=[tx transformBezierPath:path];
	}
	
	// post-rotate
	if (nubPosition==DCNubPositionRight||nubPosition==DCNubPositionLeft) {
		NSAffineTransform *tx=[NSAffineTransform transform];
		[tx rotateByDegrees:270.0];
		path=[tx transformBezierPath:path];
		tx=[NSAffineTransform transform];
		[tx translateXBy:0 yBy:rect.size.width];
		path=[tx transformBezierPath:path];
	}
	
	NSLog(@"path %@", NSStringFromRect([path bounds]));
	
	
	return path;
}

@end
