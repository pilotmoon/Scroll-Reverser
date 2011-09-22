#import <Cocoa/Cocoa.h>

@interface StatusItemController : NSWindowController <NSMenuDelegate> {
	NSStatusItem *_statusItem;
	NSImage *_statusImage;
	NSImage *_statusImageInverse;
	NSImage *_statusImageDisabled;
    NSMenu *_theMenu;
	BOOL _menuIsOpen;
}
- (void)attachMenu:(NSMenu *)menu;

@end
