// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "StatusItemController.h"

@implementation StatusItemController

+ (NSSize)statusImageSize
{
    return NSMakeSize(14, 17);
}

+ (NSImage *)statusImageWithColor:(NSColor *)color
{
    NSImage *const templateImage=[NSImage imageNamed:@"ScrollReverserStatusIcon"];
    
    // create blank image to draw into
    NSImage *const statusImage=[[NSImage alloc] init];
    [statusImage setSize:[self statusImageSize]];
    [statusImage lockFocus];
    
    // draw base black image
    const NSRect dstRect=NSMakeRect(0, 0, [self statusImageSize].width, [self statusImageSize].height);
    [templateImage drawInRect:dstRect
                     fromRect:NSZeroRect
                    operation:NSCompositingOperationSourceOver
                     fraction:1.0];
    
    // fill with color
    [color set];
    NSRectFillUsingOperation(dstRect, NSCompositingOperationSourceIn);
    
    // finished drawing
    [statusImage unlockFocus];
    return statusImage;
}

- (void)updateItems
{
    if ([_statusItem respondsToSelector:@selector(button)]) {
        [_statusItem button].appearsDisabled=!self.enabled;
    }
    else {
        if (self.enabled) {
            if (_menuIsOpen) {
                [_statusItem setImage:[StatusItemController statusImageWithColor:[NSColor whiteColor]]];
            }
            else {
                [_statusItem setImage:[StatusItemController statusImageWithColor:[NSColor blackColor]]];
            }
        }
        else {
            [_statusItem setImage:[StatusItemController statusImageWithColor:[NSColor grayColor]]];
        }
    }
}

- (void)addStatusIcon
{
	if (!_statusItem) {
		_statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        [_statusItem setHighlightMode:YES];
        [_statusItem setTarget:self];
        [_statusItem setAction:@selector(statusButtonClicked:)];
        [_statusItem sendActionOn:NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown];

        if ([_statusItem respondsToSelector:@selector(button)]) {
			// on yosemite, set up the template image here
            NSImage *const statusImage=[StatusItemController statusImageWithColor:[NSColor blackColor]];
            [statusImage setTemplate:YES];
            [_statusItem setImage:statusImage];
        }
	}
}

- (void)removeStatusIcon
{
	if (_statusItem) {
		[[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
		_statusItem=nil;
	}
}

- (void)displayStatusIcon
{
	if (self.visible) {
        [self addStatusIcon];
        [self updateItems];
	}
	else {
		[self removeStatusIcon];
	}
}

- (id)init
{
	self = [super init];
    if (self) {
        [self addObserver:self forKeyPath:@"enabled" options:0 context:0];
        [self addObserver:self forKeyPath:@"visible" options:0 context:0];
        [self displayStatusIcon];
    }
	return self;
}

- (void)menuWillOpen:(NSMenu *)menu
{
	_menuIsOpen=YES;
	[self updateItems];
}

- (void)menuDidClose:(NSMenu *)menu
{
	_menuIsOpen=NO;
	[self updateItems];	
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self displayStatusIcon];
}

- (void)attachMenu:(NSMenu *)menu
{
    _theMenu=menu;
    [_theMenu setDelegate:self];
}

- (void)openMenu
{
    if (_theMenu) {
        [_statusItem popUpStatusItemMenu:_theMenu];
    }
}

- (void)statusButtonClicked:(id)sender
{
    if ((([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagControl)==NSEventModifierFlagControl) ||
        [[NSApp currentEvent] type]==NSEventTypeRightMouseDown)
    {
        [_statusItemDelegate statusItemRightClicked];
    }
    else if (([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagOption)==NSEventModifierFlagOption) {
        [_statusItemDelegate statusItemAltClicked];
    }
    else {
        [_statusItemDelegate statusItemClicked];
        [self openMenu];
    }
}

@end
