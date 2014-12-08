//
//  PrefsWindowController.m
//  ScrollInverter
//
//  Created by Nicholas Moore on 08/12/2014.
//
//

#import "PrefsWindowController.h"
#import "ScrollInverterAppDelegate.h"

@interface PrefsWindowController ()

@end

@implementation PrefsWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)showWindow:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    [[self window] setLevel:NSFloatingWindowLevel];
    [[self window] center];
    [super showWindow:sender];
}

- (IBAction)closeWelcomeWindow:(id)sender
{
    [self close];
}

- (ScrollInverterAppDelegate *)appDelegate
{
    return [[NSApplication sharedApplication] delegate];
}

- (NSString *)menuStringReverseScrolling
{
    return [[self appDelegate] menuStringReverseScrolling];
}

- (NSString *)menuStringSRPreferences {
    return NSLocalizedString(@"Scroll Reverser Preferences", nil);
}

- (NSString *)menuStringScrollingAxes {
    return NSLocalizedString(@"Scrolling Axes", nil);
}

- (NSString *)menuStringScrollingDevices {
    return NSLocalizedString(@"Scrolling Devices", nil);
}

- (NSString *)menuStringAppSettings {
    return NSLocalizedString(@"App Settings", nil);
}

- (NSString *)menuStringCheckForUpdates {
    return NSLocalizedString(@"Check for updates", nil);
}

- (NSString *)menuStringCheckNow {
    return NSLocalizedString(@"Check Now", nil);
}

- (NSString *)menuStringStartAtLogin {
    return NSLocalizedString(@"Start at Login", nil);
}

- (NSString *)menuStringShowInMenuBar {
    return NSLocalizedString(@"Show in Menu Bar", nil);
}

- (NSString *)menuStringHorizontal {
    return NSLocalizedString(@"Reverse Horizontal", nil);
}

- (NSString *)menuStringVertical {
    return NSLocalizedString(@"Reverse Vertical", nil);
}

- (NSString *)menuStringTrackpad {
    return NSLocalizedString(@"Reverse Trackpad", nil);
}

- (NSString *)menuStringMouse {
    return NSLocalizedString(@"Reverse Mouse", nil);
}

- (NSString *)menuStringTablet {
    return NSLocalizedString(@"Reverse Tablet", nil);
}

@end
