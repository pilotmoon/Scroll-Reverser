// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

@class AppDelegate, LinkView;

#import <Cocoa/Cocoa.h>

@interface PrefsWindowController : NSWindowController <NSTabViewDelegate, NSToolbarDelegate, NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate>

@property (readonly) AppDelegate *appDelegate;

@property (weak) IBOutlet NSView *scrollingSettings;
@property (weak) IBOutlet NSView *appSettings;
@property (weak) IBOutlet LinkView *linkView;
@property (weak) IBOutlet NSWindow *permissionsSheet;
@property (weak) IBOutlet NSTableView *permissionsTableView;

@property (readonly) NSString *menuStringReverseScrolling;
@property (readonly) NSString *menuStringPreferencesTitle;
@property (readonly) NSString *menuStringScrollingSettings;
@property (readonly) NSString *menuStringAppSettings;
@property (readonly) NSString *menuStringScrollingAxes;
@property (readonly) NSString *menuStringScrollingDevices;
@property (readonly) NSString *menuStringCheckForUpdates;
@property (readonly) NSString *menuStringCheckNow;
@property (readonly) NSString *menuStringStartAtLogin;
@property (readonly) NSString *menuStringShowInMenuBar;
@property (readonly) NSString *menuStringHorizontal;
@property (readonly) NSString *menuStringVertical;
@property (readonly) NSString *menuStringTrackpad;
@property (readonly) NSString *menuStringMouse;
@property (readonly) NSString *menuStringTablet;
@property (readonly) NSString *menuStringPermissionsTableHeader;
@property (readonly) NSString *menuStringClose;


- (IBAction)showPermissionsSheet:(id)sender;
- (IBAction)closePermissionsSheet:(id)sender;
- (IBAction)buttonPermissionsHelpClicked:(id)sender;

@end
