#import <Cocoa/Cocoa.h>
@class MouseTap, FCAboutController, DCWelcomeWindowController;

@interface ScrollInverterAppDelegate : NSObject {
	MouseTap *tap;
	NSStatusItem *statusItem;
	IBOutlet NSMenu *statusMenu;
	NSImage *statusImage;
	NSImage *statusImageDisabled;
	NSImage *statusImageInverse;
	FCAboutController *aboutController;
	DCWelcomeWindowController *welcomeController;
}
- (IBAction)showAbout:(id)sender;
@end
