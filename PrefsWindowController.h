//
//  PrefsWindowController.h
//  ScrollInverter
//
//  Created by Nicholas Moore on 08/12/2014.
//
//
@class ScrollInverterAppDelegate, LinkView;

#import <Cocoa/Cocoa.h>

@interface PrefsWindowController : NSWindowController <NSTabViewDelegate, NSToolbarDelegate>

@property (readonly) ScrollInverterAppDelegate *appDelegate;

@property (weak) IBOutlet NSView *scrollingSettings;
@property (weak) IBOutlet NSView *appSettings;
@property (weak) IBOutlet LinkView *linkView;

@property (readonly) NSString *menuStringReverseScrolling;
@property (readonly) NSString *menuStringAppVersion;
@property (readonly) NSString *menuStringAppCredit;
@property (readonly) NSString *menuStringAppLink;
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
@end
