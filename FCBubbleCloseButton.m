//
//  FCBubbleCloseButton.m
//  fc
//
//  Created by Work on 25/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "FCBubbleCloseButton.h"
#import "NSImage+CopySize.h"

@implementation FCBubbleCloseButton

- (id)initWithFrame:(NSRect)frameRect
{
	self=[super initWithFrame:frameRect];
	if (self) {
		[[self cell] setImage:[[[NSImage imageNamed:@"XIcon"] copyWithSize:frameRect.size] autorelease]];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self=[super initWithCoder:aDecoder];
	if(self) {
		[[self cell] setImage:[[[NSImage imageNamed:@"XIcon"] copyWithSize:[self frame].size] autorelease]];
		[[self cell] setAlternateImage:[[[NSImage imageNamed:@"XIcon"] copyWithSize:[self frame].size] autorelease]];
	}
	return self;
}


@end
