#import <Cocoa/Cocoa.h>
@class MouseTap, StatusItemController, LoginItemsController, WelcomeWindowController, PrefsWindowController, DebugWindowController, TapLogger;

extern NSString *const PrefsReverseScrolling;
extern NSString *const PrefsReverseHorizontal;
extern NSString *const PrefsReverseVertical;
extern NSString *const PrefsReverseTrackpad;
extern NSString *const PrefsReverseMouse;
extern NSString *const PrefsReverseTablet;
extern NSString *const PrefsHideIcon;

@interface AppDelegate : NSObject {
	MouseTap *tap;
	StatusItemController *statusController;
    LoginItemsController *loginItemsController;
    WelcomeWindowController *welcomeWindowController;
    PrefsWindowController *prefsWindowController;
    DebugWindowController *debugWindowController;
    TapLogger *logger;
    
    IBOutlet NSMenu *statusMenu;
}

@property (weak) IBOutlet NSMenu *theMainMenu;

@property (readonly) NSString *appName;
@property (readonly) NSString *appVersion;
@property (readonly) NSString *appCredit;
@property (readonly) NSURL *appLink;
@property (readonly) NSString *appDisplayLink;

@property (readonly) NSString *menuStringReverseScrolling;
@property (readonly) NSString *menuStringAbout;
@property (readonly) NSString *menuStringPreferences;
@property (readonly) NSString *menuStringQuit;

- (IBAction)showPrefs:(id)sender;
- (IBAction)showAbout:(id)sender;

- (void)statusItemClicked;
- (void)statusItemRightClicked;
- (void)statusItemAltClicked;

- (void)logAppEvent:(NSString *)str;

@end
