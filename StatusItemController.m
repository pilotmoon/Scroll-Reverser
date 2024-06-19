// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "StatusItemController.h"

@interface StatusItemController () <NSMenuDelegate>
@property NSStatusItem *statusItem;
@property NSMenu *theMenu;
@property BOOL menuIsOpen;
@end

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
    if ([self.statusItem respondsToSelector:@selector(button)]) {
        [self.statusItem button].appearsDisabled=!self.enabled;
    }
    else {
        if (self.enabled) {
            if (self.menuIsOpen) {
                [self.statusItem setImage:[StatusItemController statusImageWithColor:[NSColor whiteColor]]];
            }
            else {
                [self.statusItem setImage:[StatusItemController statusImageWithColor:[NSColor blackColor]]];
            }
        }
        else {
            [self.statusItem setImage:[StatusItemController statusImageWithColor:[NSColor grayColor]]];
        }
    }
}

- (void)addStatusIcon
{
    if (!self.statusItem) {
        self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        [self.statusItem setHighlightMode:YES];
        [self.statusItem setTarget:self];
        [self.statusItem setAction:@selector(statusButtonClicked:)];
        [self.statusItem sendActionOn:NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown];

        if ([self.statusItem respondsToSelector:@selector(button)]) {
            // on yosemite, set up the template image here
            NSImage *const statusImage=[StatusItemController statusImageWithColor:[NSColor blackColor]];
            [statusImage setTemplate:YES];
            [self.statusItem setImage:statusImage];
        }
    }
}

- (void)removeStatusIcon
{
    if (self.statusItem) {
        [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
        self.statusItem=nil;
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
    self.menuIsOpen=YES;
    [self updateItems];
}

- (void)menuDidClose:(NSMenu *)menu
{
    self.menuIsOpen=NO;
    [self updateItems];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self displayStatusIcon];
}

- (void)attachMenu:(NSMenu *)menu
{
    self.theMenu=menu;
    [self.theMenu setDelegate:self];
}

- (void)openMenu
{
    [self.statusItem.button performClick:nil];
}

- (void)statusButtonClicked:(id)sender
{
    if ((([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagControl)==NSEventModifierFlagControl) ||
        [[NSApp currentEvent] type]==NSEventTypeRightMouseDown)
    {
        [self.statusItemDelegate statusItemRightClicked];
    }
    else if (([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagOption)==NSEventModifierFlagOption) {
        [self.statusItemDelegate statusItemAltClicked];
    }
    else {
        [self.statusItemDelegate statusItemClicked];
        [self openMenu];
    }
}

@end
