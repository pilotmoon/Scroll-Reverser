#import <Cocoa/Cocoa.h>
@class MouseTap;

@interface ScrollInverterAppDelegate : NSObject {
	MouseTap *tap;
	NSStatusItem *statusItem;
	IBOutlet NSMenu *statusMenu;
	NSImage *statusImage;
	NSImage *statusImageDisabled;
	NSImage *statusImageInverse;
}
- (IBAction)showAbout:(id)sender;
@end
