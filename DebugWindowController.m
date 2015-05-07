//
//  DebugWindowController.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import "DebugWindowController.h"

@interface DebugWindowController ()

@end

@implementation DebugWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)showWindow:(id)sender
{
    [[self window] setLevel:NSFloatingWindowLevel];
    [[self window] center];
    [NSApp activateIgnoringOtherApps:YES];
    // small delay to prevent flash of window drawing
    dispatch_after(0.05, dispatch_get_main_queue(), ^{
        [super showWindow:sender];
    });
}

- (NSString *)uiStringDebugConsole {
    return @"Scroll Reverser Debug Console";
}
- (NSString *)uiStringClear {
    return @"Clear";
}

@end

