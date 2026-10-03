// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "WelcomeWindowController.h"

@implementation WelcomeWindowController

- (instancetype)init
{
    NSWindow *const window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 213, 192)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:YES];
    window.releasedWhenClosed=NO;

    self=[super initWithWindow:window];
    if (self) {
        NSView *const contentView=window.contentView;

        NSTextField *const welcomeLabel=[NSTextField wrappingLabelWithString:NSLocalizedString(@"Scroll Reverser is now running!", nil)];
        welcomeLabel.frame=NSMakeRect(18, 147, 179, 34);
        welcomeLabel.alignment=NSTextAlignmentCenter;
        welcomeLabel.selectable=NO;
        [contentView addSubview:welcomeLabel];

        // the menu bar picture, with the help text drawn over its dark area
        NSImageView *const imageView=[NSImageView imageViewWithImage:[NSImage imageNamed:@"IntroShot"]];
        imageView.frame=NSMakeRect(19, 61, 175, 71);
        imageView.imageScaling=NSImageScaleProportionallyUpOrDown;
        [contentView addSubview:imageView];

        NSTextField *const iconHelpLabel=[NSTextField wrappingLabelWithString:NSLocalizedString(@"For settings, click the icon in the menu bar", nil)];
        iconHelpLabel.frame=NSMakeRect(23, 72, 168, 28);
        iconHelpLabel.alignment=NSTextAlignmentCenter;
        iconHelpLabel.selectable=NO;
        iconHelpLabel.font=[NSFont messageFontOfSize:11];
        iconHelpLabel.textColor=[NSColor colorWithDeviceRed:0.988 green:1 blue:0.996 alpha:1];
        [contentView addSubview:iconHelpLabel];

        NSButton *const okButton=[NSButton buttonWithTitle:NSLocalizedString(@"OK", nil) target:self action:@selector(closeWelcomeWindow:)];
        okButton.frame=NSMakeRect(63, 13, 86, 32);
        okButton.keyEquivalent=@"\r";
        [contentView addSubview:okButton];
    }
    return self;
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

@end
