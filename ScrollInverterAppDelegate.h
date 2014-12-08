#import <Cocoa/Cocoa.h>
@class MouseTap, StatusItemController, LoginItemsController, WelcomeWindowController, PrefsWindowController;

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
    PrefsWindowController *prefsWindowController;

    IBOutlet NSMenu *statusMenu;
    IBOutlet NSMenuItem *startAtLoginMenu;
}
@property (readonly) NSString *menuStringReverseScrolling;
@property (readonly) NSString *menuStringAbout;
@property (readonly) NSString *menuStringPreferences;
@property (readonly) NSString *menuStringQuit;

- (IBAction)showPrefs:(id)sender;
- (IBAction)showAbout:(id)sender;
@end
