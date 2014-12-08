#import <Cocoa/Cocoa.h>

@interface StatusItemController : NSWindowController <NSMenuDelegate> {
	NSStatusItem *_statusItem;
    NSMenu *_theMenu;
	BOOL _menuIsOpen;
}

- (void)attachMenu:(NSMenu *)menu;
- (void)openMenu;

@end
