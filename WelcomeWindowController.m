// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// (c) Nicholas Moore. Licensed under Apache License v2.0 (see LICENSE).

#import "WelcomeWindowController.h"

@implementation WelcomeWindowController

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

- (NSString *)menuStringWelcomeText {
	return NSLocalizedString(@"Scroll Reverser is now running!", nil);
}
- (NSString *)menuStringWelcomeIconHelp {
	return NSLocalizedString(@"For settings, click the icon in the menu bar", nil);
}
- (NSString *)menuStringOK {
	return NSLocalizedString(@"OK", nil);
}

@end
