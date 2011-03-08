//
//  DCStatusItemController.h
//  dc
//
//  Created by Work on 20/12/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class DCStatusItem;

@interface DCStatusItemController : NSWindowController {
	NSStatusItem *statusItem;
	NSImage *statusImage;
	NSImage *statusImageInverse;
	NSImage *statusImageDisabled;
	BOOL menuIsOpen;
	BOOL canOpenMenu;
	NSMenu *theMenu;

	NSUInteger animPos;
	NSTimer *animTimer;
}
@property (readonly) NSStatusItem *statusItem;
@property (readonly) BOOL menuIsOpen;

- (void)attachedMenuWillOpen;
- (void)attachedMenuDidClose;
- (void)attachMenu:(NSMenu *)menu;
- (void)showAttachedMenu:(BOOL)force;
- (void)showAttachedMenu;
- (NSRect)statusItemRect;

@end
