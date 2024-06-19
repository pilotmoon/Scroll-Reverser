// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>

@protocol StatusItemControllerDelegate <NSObject>
@required
- (void) statusItemRightClicked;
- (void) statusItemAltClicked;
- (void) statusItemClicked;
@end

@interface StatusItemController : NSWindowController <NSMenuDelegate>

@property id<StatusItemControllerDelegate> statusItemDelegate;
@property (getter=isEnabled) BOOL enabled;
@property (getter=isVisible) BOOL visible;

- (void)attachMenu:(NSMenu *)menu;
- (void)openMenu;

@end
