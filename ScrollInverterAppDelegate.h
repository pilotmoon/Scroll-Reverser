#import <Cocoa/Cocoa.h>
@class MouseTap, StatusItemController, LoginItemsController, WelcomeWindowController;

extern NSString *const PrefsReverseScrolling;
extern NSString *const PrefsReverseHorizontal;
extern NSString *const PrefsReverseVertical;
extern NSString *const PrefsReverseTrackpad;
extern NSString *const PrefsReverseMouse;
extern NSString *const PrefsReverseTablet;
extern NSString *const PrefsHideIcon;

@interface ScrollInverterAppDelegate : NSObject {
	MouseTap *tap;
	StatusItemController *statusController;
    LoginItemsController *loginItemsController;
    WelcomeWindowController *welcomeWindowController;
    IBOutlet NSMenu *statusMenu;
    IBOutlet NSMenu *prefsMenu;
    IBOutlet NSMenuItem *trackpadItemMenu;
    IBOutlet NSMenuItem *startAtLoginMenu;
	IBOutlet NSMenuItem *startAtLoginSeparator;	
}
- (IBAction)showAbout:(id)sender;
- (IBAction)menuItemClicked:(id)sender;

@end
