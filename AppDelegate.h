// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>
#import "StatusItemController.h"
#import "PermissionsManager.h"
#import "LauncherController.h"
#import <Sparkle/Sparkle.h>

@class MouseTap, WelcomeWindowController, PrefsWindowController, DebugWindowController, TapLogger, TestWindowController;

extern NSString *const PrefsReverseScrolling;
extern NSString *const PrefsReverseHorizontal;
extern NSString *const PrefsReverseVertical;
extern NSString *const PrefsReverseTrackpad;
extern NSString *const PrefsReverseMouse;
extern NSString *const PrefsHideIcon;

@interface AppDelegate : NSObject <NSApplicationDelegate, StatusItemControllerDelegate, SUUpdaterDelegate> {
}

@property (readonly) PermissionsManager *permissionsManager;
@property (readonly) LauncherController *launcherController;

@property (weak) IBOutlet NSMenu *theMainMenu;
@property (weak) IBOutlet NSMenu *statusMenu;

@property (readonly) NSString *appName;
@property (readonly) NSString *appVersion;
@property (readonly) NSString *appCredit;
@property (readonly) NSURL *appLink;
@property (readonly) NSString *appDisplayLink;
@property (readonly) NSURL *appPermissionsHelpLink;

@property (readonly) NSString *menuStringReverseScrolling;
@property (readonly) NSString *menuStringPreferences;
@property (readonly) NSString *menuStringQuit;

@property (getter=isEnabled) BOOL enabled;

- (IBAction)showDebug:(id)sender;
- (IBAction)showPrefs:(id)sender;
- (IBAction)showAbout:(id)sender;
- (IBAction)showTestWindow:(id)sender;

- (void)statusItemClicked;
- (void)statusItemRightClicked;
- (void)statusItemAltClicked;

- (void)refreshPermissions;

- (void)logAppEvent:(NSString *)str;

@end
