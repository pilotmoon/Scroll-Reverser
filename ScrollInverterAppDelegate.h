#import <Cocoa/Cocoa.h>
@class MouseTap, FCAboutController, DCWelcomeWindowController, StatusItemController;

extern NSString *const PrefsReverseScrolling;
extern NSString *const PrefsReverseHorizontal;
extern NSString *const PrefsReverseVertical;
extern NSString *const PrefsReverseTrackpad;
extern NSString *const PrefsReverseMouse;
extern NSString *const PrefsReverseTablet;
extern NSString *const PrefsHideIcon;

@interface ScrollInverterAppDelegate : NSObject {
	MouseTap *tap;
	IBOutlet NSMenu *statusMenu;
	FCAboutController *aboutController;
	DCWelcomeWindowController *welcomeController;
	StatusItemController *statusController;
}
- (IBAction)showAbout:(id)sender;
@end
