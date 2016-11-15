// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// (c) Nicholas Moore. Licensed under Apache License v2.0 (see LICENSE).

#import <Cocoa/Cocoa.h>

@interface StatusItemController : NSWindowController <NSMenuDelegate> {
	NSStatusItem *_statusItem;
    NSMenu *_theMenu;
	BOOL _menuIsOpen;
}

- (void)attachMenu:(NSMenu *)menu;
- (void)openMenu;

@end
