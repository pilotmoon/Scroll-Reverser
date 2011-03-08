//
//  NSBezierPath+Nub.h
//  WindowTest
//
//  Created by Work on 12/11/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
	DCNubPositionBottom,
	DCNubPositionRight,
	DCNubPositionTop,
	DCNubPositionLeft
} DCNubPosition;

@interface NSBezierPath (Nub) 

+ (NSBezierPath *)bezierPathWithNubRect:(NSRect)boxRect
								 radius:(CGFloat)radius
							nubPosition:(DCNubPosition)nubPosition
								nubSize:(CGFloat)nubSize
							  nubOffset:(CGFloat)nubOffset;
@end
