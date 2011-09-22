#import <Cocoa/Cocoa.h>

@interface StatusItemController : NSWindowController <NSMenuDelegate> {
	NSStatusItem *statusItem;
	NSImage *statusImage;
	NSImage *statusImageInverse;
	NSImage *statusImageDisabled;
	BOOL menuIsOpen;
	BOOL canOpenMenu;
	NSMenu *theMenu;
}
@property (readonly) NSStatusItem *statusItem;
@property (readonly) BOOL menuIsOpen;

- (void)attachMenu:(NSMenu *)menu;
- (void)showAttachedMenu:(BOOL)force;
- (void)showAttachedMenu;

@end
