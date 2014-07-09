#import <Cocoa/Cocoa.h>

@interface StatusItemController : NSWindowController {
	NSStatusItem *_statusItem;
	NSImage *_statusImage;
    NSMenu *_theMenu;
}

- (void)attachMenu:(NSMenu *)menu;

@end
