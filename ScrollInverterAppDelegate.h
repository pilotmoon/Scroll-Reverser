#import <Cocoa/Cocoa.h>
@class MouseTap, FCAboutController, DCWelcomeWindowController, DCStatusItemController;

extern NSString *const PrefsInvertScrolling;
extern NSString *const PrefsHideIcon;

@interface ScrollInverterAppDelegate : NSObject {
	MouseTap *tap;
	IBOutlet NSMenu *statusMenu;
	FCAboutController *aboutController;
	DCWelcomeWindowController *welcomeController;
	DCStatusItemController *statusController;
}
- (IBAction)showAbout:(id)sender;
- (IBAction)hideIcon:(id)sender;
@end
