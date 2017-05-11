// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>
#import "StatusItemController.h"
@class MouseTap, LoginItemsController, WelcomeWindowController, PrefsWindowController, DebugWindowController, TapLogger, TestWindowController;

extern NSString *const PrefsReverseScrolling;
extern NSString *const PrefsReverseHorizontal;
extern NSString *const PrefsReverseVertical;
extern NSString *const PrefsReverseTrackpad;
extern NSString *const PrefsReverseMouse;
extern NSString *const PrefsReverseTablet;
extern NSString *const PrefsHideIcon;

@interface AppDelegate : NSObject <StatusItemControllerDelegate> {
    BOOL quitting;
	MouseTap *tap;
	StatusItemController *statusController;
    LoginItemsController *loginItemsController;
    WelcomeWindowController *welcomeWindowController;
    PrefsWindowController *prefsWindowController;
    DebugWindowController *debugWindowController;
    TestWindowController *testWindowController;
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

- (IBAction)showDebug:(id)sender;
- (IBAction)showPrefs:(id)sender;
- (IBAction)showAbout:(id)sender;
- (IBAction)showTestWindow:(id)sender;

- (void)statusItemClicked;
- (void)statusItemRightClicked;
- (void)statusItemAltClicked;

- (void)logAppEvent:(NSString *)str;

@end
