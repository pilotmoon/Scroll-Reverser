//
//  FCImageButtonCell.m
//  fc
//
//  Created by Work on 15/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "FCImageButton.h"
#import "FCImageButtonCell.h"
#import "NSImage+CopySize.h"

@implementation FCImageButtonCell

- (void)drawWithFrame:(NSRect)frame inView:(FCImageButton *)controlView
{
	NSRect vframe=[controlView bounds];
	NSImage *srcImage=[self state]?[self alternateImage]:[self image];
	NSImage *img=[srcImage copyWithSize:vframe.size];
	
	CGFloat fraction=0.7;
	if ([self isHighlighted]) {
		fraction=1.0;
	}
	else if([controlView mouseIn]) {
		fraction=0.9;
	}

	[img drawInRect:vframe fromRect:vframe operation:NSCompositeSourceOver fraction:fraction];
}
@end
