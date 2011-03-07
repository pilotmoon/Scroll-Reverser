#import <Cocoa/Cocoa.h>
@class MouseTap, FCAboutController;

@interface ScrollInverterAppDelegate : NSObject {
	MouseTap *tap;
	NSStatusItem *statusItem;
	IBOutlet NSMenu *statusMenu;
	NSImage *statusImage;
	NSImage *statusImageDisabled;
	NSImage *statusImageInverse;
	FCAboutController *aboutController;
}
- (IBAction)showAbout:(id)sender;
@end
