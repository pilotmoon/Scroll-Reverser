//
//  DCNubWindow.m
//  dc
//
//  Created by Work on 15/11/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "DCNubWindow.h"

#define CORNER_RADIUS (6.0)

@implementation DCNubWindow
@synthesize nubLocation, boxSize, nubPosition, nubSize, nubOffset, nubWindowPath, nubWindowFrame, boxFrame, avoidEdgeOverlap;

static NSRect _pointScreenRect(NSPoint point)
{
	for (NSScreen * s in [NSScreen screens])
	{
		NSRect frame=[s frame];
		if (NSPointInRect(point, frame)) {
			return frame;
		}
	}
	return NSZeroRect;
}

static CGFloat _nubOffset(CGFloat aBoxSide, CGFloat aPoint, CGFloat aNubSize, CGFloat aMin, CGFloat aMax, CGFloat aCornerRadius, BOOL avoidEdges)
{
	CGFloat halfSide=aBoxSide*0.5;
	CGFloat overlap=0;
	
	if (avoidEdges) {
		CGFloat boxLeft=aPoint-halfSide;
		CGFloat boxRight=aPoint+halfSide;
		CGFloat maxOverlap=halfSide-aNubSize-aCornerRadius;
		
		if (boxLeft<aMin) {
			overlap=boxLeft-aMin;
			if (overlap<(-maxOverlap)) {
				overlap=(-maxOverlap);
			}
		}
		else if (boxRight>aMax) {
			overlap=boxRight-aMax;		
			if (overlap>maxOverlap) {
				overlap=maxOverlap;
			}
		}		
	}
	
	return halfSide+overlap;		 
}
	
- (CGFloat)cornerRadius
{
	return 6.0;
}

// update the current path
- (void)updateGeometry
{
	// calculate container and nub offset
	NSRect container=NSZeroRect;	
	container.size=boxSize;	
	boxFrame=container;
	
	// find screen containing mouse
	NSRect mouseScreenRect=_pointScreenRect(nubLocation);
	switch (nubPosition) {
		case DCNubPositionBottom:
		case DCNubPositionTop:		
			nubOffset=_nubOffset(boxSize.width, nubLocation.x, nubSize,
								 mouseScreenRect.origin.x, mouseScreenRect.origin.x+NSWidth(mouseScreenRect), [self cornerRadius], self.avoidEdgeOverlap);
			container.size.height+=nubSize;
			break;
		case DCNubPositionRight:
		case DCNubPositionLeft:
			nubOffset=_nubOffset(boxSize.height, nubLocation.y, nubSize,
								 mouseScreenRect.origin.y, mouseScreenRect.origin.y+NSHeight(mouseScreenRect), [self cornerRadius], self.avoidEdgeOverlap);
			container.size.width+=nubSize;
			break;
		default:
			break;
	}
	
	// caluclate window path
	[nubWindowPath release];
	nubWindowPath=[[NSBezierPath bezierPathWithNubRect:container
											   radius:[self cornerRadius]
										  nubPosition:nubPosition
											  nubSize:nubSize 
											nubOffset:nubOffset] retain];
	
	// calculate relative nub location
	NSPoint nubLocationRelative=NSZeroPoint;
	switch (nubPosition) {
		case DCNubPositionBottom:
			boxFrame.origin.y+=nubSize;
			nubLocationRelative=NSMakePoint(nubOffset, -1);
			break;
		case DCNubPositionLeft:		
			boxFrame.origin.x+=nubSize;
			nubLocationRelative=NSMakePoint(-1, nubOffset);
			break;
		case DCNubPositionTop:
			nubLocationRelative=NSMakePoint(nubOffset, NSHeight(container)+1);
			break;
		case DCNubPositionRight:
			nubLocationRelative=NSMakePoint(NSWidth(container)+1, nubOffset);
			break;
		default:
			break;
	}
	
	// calculate frame 
	nubWindowFrame=container;
	nubWindowFrame.origin.x+=nubLocation.x-nubLocationRelative.x;
	nubWindowFrame.origin.y+=nubLocation.y-nubLocationRelative.y;
}

// redraw with current geometry
- (void)drawNubWindow
{
	[self setFrame:nubWindowFrame display:YES];
}

#pragma mark Compound setters

// set all 4 params
- (void)setBoxSize:(NSSize)aBoxSize
	   nubLocation:(NSPoint)aNubLocation
	   nubPosition:(DCNubPosition)aNubPosition
		   nubSize:(CGFloat)aNubSize
{
	boxSize=aBoxSize;
	nubLocation=aNubLocation;
	nubPosition=aNubPosition;
	nubSize=aNubSize;
	[self updateGeometry];
}

// just set size and location
- (void)setBoxSize:(NSSize)aBoxSize
	   nubLocation:(NSPoint)aNubLocation
{
	boxSize=aBoxSize;
	nubLocation=aNubLocation;
	[self updateGeometry];
}

#pragma mark Observer for single setters

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	[self updateGeometry];
}

#pragma mark Initializers

// designated initializer
- (id)initWithBoxSize:(NSSize)aBoxSize
		  nubLocation:(NSPoint)aNubLocation
		  nubPosition:(DCNubPosition)aNubPosition
			  nubSize:(CGFloat)aNubSize
{
	// start with zero window
    [super initWithContentRect:NSZeroRect
					 styleMask:NSBorderlessWindowMask|NSUtilityWindowMask|NSNonactivatingPanelMask
					   backing:NSBackingStoreBuffered
						 defer:NO];
    if (!self) return nil;
	
	// set window parameters
	[self setOpaque:NO];
	[self setBackgroundColor:[NSColor clearColor]];
	
	// set observer for changes
	[self addObserver:self forKeyPath:@"boxSize" options:0 context:0];
	[self addObserver:self forKeyPath:@"nubLocation" options:0 context:0];
	[self addObserver:self forKeyPath:@"nubPosition" options:0 context:0];
	[self addObserver:self forKeyPath:@"nubSize" options:0 context:0];
	
	// set overlap param
	[self setAvoidEdgeOverlap:YES];
	
	// set geometry
	[self setBoxSize:aBoxSize
		 nubLocation:aNubLocation
		 nubPosition:aNubPosition
			 nubSize:aNubSize];		

    return self;
}

@end
