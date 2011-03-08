#import <Cocoa/Cocoa.h>
@class MouseTap, FCAboutController, DCWelcomeWindowController, DCStatusItemController;

extern NSString *const PrefsInvertScrolling;

@interface ScrollInverterAppDelegate : NSObject {
	MouseTap *tap;
	//NSStatusItem *statusItem;
	IBOutlet NSMenu *statusMenu;
	//NSImage *statusImage;
	//NSImage *statusImageDisabled;
	//NSImage *statusImageInverse;
	FCAboutController *aboutController;
	DCWelcomeWindowController *welcomeController;
	DCStatusItemController *statusController;
}
- (IBAction)showAbout:(id)sender;
@end
