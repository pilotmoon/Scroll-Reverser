//
//  DCStatusItemController.m
//  dc
//
//  Created by Work on 20/12/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "DCStatusItemController.h"
#import "DCStatusItemView.h"
#import "NSImage+CopySize.h"

@implementation DCStatusItemController
@synthesize statusItem, menuIsOpen;

- (void)updateItems
{
	if (menuIsOpen) {
		[(NSButton *)[statusItem view] setImage:statusImageInverse];
	}
	else {
		if (animating) {
			[(NSButton *)[statusItem view] setImage:[flashImages objectAtIndex:animPos]];
		}
		else {
			if ([DCUniversalAccessHelper sharedInstance].axEnabled&&[DCEngine sharedInstance].dwellClickOn) {
				[(NSButton *)[statusItem view] setImage:statusImage];
			}
			else {
				[(NSButton *)[statusItem view] setImage:statusImageDisabled];
			}		
			
		}
	}
	[[statusItem view] setNeedsDisplay:YES];
}

#define FRAMES (40.0f)
- (id)init
{
	self = [super init];
	
	// Loadup status icons.
	const NSSize iconSize=NSMakeSize(14, 19);
	NSImage *original=[NSImage imageNamed:@"DCIconStatus.png"];
	
	statusImage=[original copyWithSize:iconSize];
	statusImageInverse=[original copyWithSize:iconSize colorTo:[NSColor whiteColor]];
	// gray icon needs coloring before sizing due to aliasing effects
	NSImage *grayTemp=[original copyWithSize:[original size] colorTo:[NSColor colorWithDeviceRed:0.6 green:0.6 blue:0.6 alpha: 1.0]]; 
	statusImageDisabled=[grayTemp copyWithSize:iconSize];	
	
	// build status item
	float width = 22.0;
    float height = [[NSStatusBar systemStatusBar] thickness];
    NSRect viewFrame = NSMakeRect(0, 0, width, height);
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:width];
    [statusItem setView:[[DCStatusItemView alloc] initWithFrame:viewFrame controller:self]];
	[self updateItems];
	[[statusItem view] display];
	
	canOpenMenu=YES;
	
	return self;
}

- (void)setReady
{
	ready=YES;
	[self updateItems];
}

- (void)attachedMenuWillOpen
{
	DLog(@"ATTACHED will open");
	menuIsOpen=YES;
	canOpenMenu=NO;
	[self updateItems];
}

- (void)attachedMenuDidClose
{
	DLog(@"ATTACHED did close");
	menuIsOpen=NO;
	[self updateItems];	
	DCRunAsyncWithDelay(0.3, ^{ // prevent reopen if reopen occured while menu tracking (dodgy but works)
		canOpenMenu=YES;
	});
}

- (void)attachMenu:(NSMenu *)menu
{
	theMenu=menu;
}

- (void)showAttachedMenu:(BOOL)force
{
	if ([DCEngine sharedInstance].override) {
		[(DCAppDelegate *)[NSApp delegate] notifyClickedIconDuringOverride];
	}
	else if (force || (!menuIsOpen && canOpenMenu)) {
		[statusItem popUpStatusItemMenu:theMenu	];
	}
}

- (void)showAttachedMenu
{
	[self showAttachedMenu:NO];
}

- (NSRect)statusItemRect
{
	NSWindow *window=[[statusItem view] window];
	if (window) {
		return [window frame];
	}
	else {
		return NSZeroRect;
	}
}

@end
