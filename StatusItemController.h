#import <Cocoa/Cocoa.h>

#ifndef TIGER_BUILD
@interface StatusItemController : NSWindowController <NSMenuDelegate> {
#else
@interface StatusItemController : NSWindowController {
#endif

	NSStatusItem *_statusItem;
	NSImage *_statusImage;
	NSImage *_statusImageInverse;
	NSImage *_statusImageDisabled;
    NSMenu *_theMenu;
	BOOL _menuIsOpen;
}
- (void)attachMenu:(NSMenu *)menu;

@end
