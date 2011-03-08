//
//  FCButtonCell.m
//  fc
//
//  Created by Work on 04/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "FCButtonCell.h"
#import "FCButton.h"
#import "NSImage+CopySize.h"

static NSShadow *_shadow;
static NSColor *disabledColor, *enabledColor;

@interface NSCell (FCButtonCellPrivate)
- (NSDictionary *)_textAttributes;
- (NSColor *)interiorColor;
@end

@implementation FCButtonCell
@synthesize backgroundColor, borderColor;

+ (void)initialize
{
	if (self==[FCButtonCell class]) {
		_shadow=[[NSShadow alloc] init];
		[_shadow setShadowColor:[NSColor colorWithDeviceWhite:0 alpha:0.5]];
		[_shadow setShadowBlurRadius:3.0];
		[_shadow setShadowOffset:NSMakeSize(0, 0)];
		
		enabledColor = [[NSColor whiteColor] retain];
		disabledColor = [[NSColor colorWithCalibratedWhite:0.6 alpha:1] retain];
	}
}


- (void)defaults
{
	[self setButtonType:NSMomentaryPushInButton];
	[self setBezelStyle:NSRoundRectBezelStyle];
	self.backgroundColor=[NSColor colorWithDeviceWhite:0.1 alpha:1.0];
	self.borderColor=[NSColor colorWithDeviceWhite:0.04f alpha:1.0f];
}

- (id)initWithCoder:(NSCoder *)aCoder
{
	self=[super initWithCoder:aCoder];
	if (self) {
		[self defaults];
	}
	return self;
}

- (id)initTextCell:(NSString *)aString
{
	self=[super initTextCell:aString];
	if (self) {
		[self defaults];
	}
	return self;
}
- (id)initImageCell:(NSImage *)anImage
{
	self=[super initImageCell:anImage];
	if (self) {
		[self defaults];
	}
	return self;
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{
	CGFloat roundedRadius = 3.0f;
	
	// Outer border
	if (borderColor) {
		NSBezierPath *outerClip = [NSBezierPath bezierPathWithRoundedRect:frame 
																  xRadius:roundedRadius 
																  yRadius:roundedRadius];
		[outerClip addClip];
		[borderColor set];
		NSRectFill(frame);
		
	}
	CGFloat inset=borderColor?1.0f:0.0f;
	// Background fill and gradient
	NSBezierPath *backgroundPath = 
    [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame, inset, inset) 
                                    xRadius:roundedRadius 
                                    yRadius:roundedRadius];
	[backgroundPath addClip];

	[backgroundColor set];
	NSRectFill(frame);
	
	// draw the gradient
	NSRect gradBounds = [backgroundPath bounds];
	gradBounds.size.height*=0.5;
	[[[NSGradient alloc] initWithStartingColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.35]
								   endingColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.06]]
	 drawInRect:gradBounds angle:90];
	
	// Inner light stroke
	[[NSColor colorWithDeviceWhite:1.0f alpha:0.02f] setStroke];
	[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame, 2.5f, 2.5f) 
									 xRadius:roundedRadius 
									 yRadius:roundedRadius] stroke];
	
	// Draw darker overlay if button is pressed
	if([self isHighlighted]) {
		[[NSColor colorWithCalibratedWhite:0.0f alpha:0.35] setFill];
		NSRectFillUsingOperation(frame, NSCompositeSourceOver);
	}
	NSLog(@"DRAW2");
}

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSButton *)controlView
{	
	[_shadow set];
	[super drawImage:image withFrame:NSInsetRect(frame,2,2) inView:controlView];
}

- (NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSButton *)controlView
{
	return [super drawTitle:title withFrame:frame inView:controlView];
}

- (NSDictionary *)_textAttributes
{
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
	[attributes addEntriesFromDictionary:[super _textAttributes]];
	[attributes setObject:[self interiorColor] forKey:NSForegroundColorAttributeName];
	[attributes setObject:_shadow forKey:NSShadowAttributeName];
	return attributes;
}

- (NSColor *)interiorColor
{
	NSColor *interiorColor;
	
	if ([self isEnabled]&&![self isHighlighted])
		interiorColor = enabledColor;
	else
		interiorColor = disabledColor;
	
	return interiorColor;
}


@end
