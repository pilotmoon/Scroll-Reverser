// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

@class AppDelegate;

#import <Cocoa/Cocoa.h>

@interface PrefsWindowController : NSWindowController <NSTabViewDelegate, NSToolbarDelegate, NSWindowDelegate>

@property (readonly) AppDelegate *appDelegate;
@property NSNumber *stepSizeSliderValue;

- (IBAction)buttonPermissionsHelpClicked:(id)sender;
- (IBAction)buttonCheckForUpdatesClicked:(id)sender;
- (void)showPermissionsPane;
- (void)callAttention;


@end
