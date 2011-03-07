//
//  FCButton.m
//  fc
//
//  Created by Work on 04/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "FCButton.h"
#import "FCButtonCell.h"

@implementation FCButton

+ (Class)cellClass
{
	return [FCButtonCell class];
}

- (NSColor *)backgroundColor
{
	return [[self cell] backgroundColor];
}

- (void)setBackgroundColor:(NSColor *)color
{
	[[self cell] setBackgroundColor:color];
}

- (NSColor *)borderColor
{
	return [[self cell] borderColor];
}

- (void)setBorderColor:(NSColor *)color
{
	[[self cell] setBorderColor:color];
}

- (BOOL)isFlipped
{
	return YES;
}

@end
