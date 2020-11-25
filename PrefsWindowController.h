// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

@class AppDelegate, LinkView;

#import <Cocoa/Cocoa.h>

@interface PrefsWindowController : NSWindowController <NSTabViewDelegate, NSToolbarDelegate, NSWindowDelegate>

@property (readonly) AppDelegate *appDelegate;

@property (weak) IBOutlet NSView *scrollingSettings;
@property (weak) IBOutlet NSView *appSettings;
@property (weak) IBOutlet LinkView *linkView;

@property (readonly) NSString *menuStringReverseScrolling;
@property (readonly) NSString *menuStringPreferencesTitle;
@property (readonly) NSString *menuStringScrollingSettings;
@property (readonly) NSString *menuStringAppSettings;
@property (readonly) NSString *menuStringScrollingAxes;
@property (readonly) NSString *menuStringScrollingDevices;
@property (readonly) NSString *menuStringCheckForUpdates;
@property (readonly) NSString *menuStringBetaUpdates;
@property (readonly) NSString *menuStringCheckNow;
@property (readonly) NSString *menuStringStartAtLogin;
@property (readonly) NSString *menuStringShowInMenuBar;
@property (readonly) NSString *menuStringHorizontal;
@property (readonly) NSString *menuStringVertical;
@property (readonly) NSString *menuStringTrackpad;
@property (readonly) NSString *menuStringMouse;
@property (readonly) NSString *menuStringClose;
@property (readonly) NSString *menuStringPermissionsHeader;
@property (readonly) NSString *menuStringPermissionsAXDescription;
@property (readonly) NSString *menuStringPermissionsIMDescription;
@property (readonly) NSString *menuStringPermissionsAX;
@property (readonly) NSString *menuStringPermissionsIM;
@property (readonly) NSString *menuStringAXButtonLabel;
@property (readonly) NSString *menuStringAXStatus;
@property (readonly) NSString *menuStringIMButtonLabel;
@property (readonly) NSString *menuStringIMStatus;
- (IBAction)buttonPermissionsHelpClicked:(id)sender;
- (IBAction)showPermissionsPane:(id)sender;

@end
