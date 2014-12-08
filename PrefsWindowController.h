//
//  PrefsWindowController.h
//  ScrollInverter
//
//  Created by Nicholas Moore on 08/12/2014.
//
//
@class ScrollInverterAppDelegate;

#import <Cocoa/Cocoa.h>

@interface PrefsWindowController : NSWindowController
@property (readonly) ScrollInverterAppDelegate *appDelegate;
@property (readonly) NSString *menuStringReverseScrolling;
@property (readonly) NSString *menuStringSRPreferences;
@property (readonly) NSString *menuStringScrollingAxes;
@property (readonly) NSString *menuStringScrollingDevices;
@property (readonly) NSString *menuStringAppSettings;
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
