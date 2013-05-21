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
- (NSString *)menuStringCheckForUpdates {
	return NSLocalizedString(@"Check For Updates", nil);
}

@end
