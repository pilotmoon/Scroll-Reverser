//
//  DCNubWindow.h
//  dc
//
//  Created by Work on 15/11/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSBezierPath+Nub.h"
#define GLOSSY

@interface DCNubWindow : NSPanel {
	
	/**************************
	 The 4 principal parameters
	 **************************/
	
	// where the nub should point to
	NSPoint nubLocation;
	
	// size of the box part of the window
	NSSize boxSize;
	
	// top/bottom/left/right
	DCNubPosition nubPosition;
	
	// how far it sticks out 
	CGFloat nubSize;
	
	// should the nub move when window is near edge
	BOOL avoidEdgeOverlap;
	
	/*********************
	 Internally calculated
	 *********************/
	// offset of nub 
	CGFloat nubOffset;
	// the actual path that defines the window
	NSBezierPath *nubWindowPath;
	// window frame
	NSRect nubWindowFrame;
	// frame of box (window coords)
	NSRect boxFrame;
}
@property (readwrite) NSPoint nubLocation;
@property (readwrite) NSSize boxSize;
@property (readwrite) DCNubPosition nubPosition;
@property (readwrite) CGFloat nubSize;
@property (readwrite) BOOL avoidEdgeOverlap;

@property (readonly) CGFloat nubOffset;
@property (readonly) NSBezierPath *nubWindowPath;
@property (readonly) NSRect	nubWindowFrame;
@property (readonly) NSRect	boxFrame;

- (id)initWithBoxSize:(NSSize)aBoxSize
		  nubLocation:(NSPoint)aNubLocation
		  nubPosition:(DCNubPosition)aNubPosition
			  nubSize:(CGFloat)aNubSize;

- (void)setBoxSize:(NSSize)aBoxSize
	   nubLocation:(NSPoint)aNubLocation
	   nubPosition:(DCNubPosition)aNubPosition
		   nubSize:(CGFloat)aNubSize;

- (void)setBoxSize:(NSSize)aBoxSize
	   nubLocation:(NSPoint)aNubLocation;

- (void)drawNubWindow;

- (CGFloat)cornerRadius;

@end
