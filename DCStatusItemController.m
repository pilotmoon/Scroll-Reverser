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
#import "ScrollInverterAppDelegate.h"
#import "NSObject+ObservePrefs.h"

@implementation DCStatusItemController
@synthesize statusItem, menuIsOpen;

- (void)updateItems
{
	NSLog(@"update");
	if (menuIsOpen) {
		[(NSButton *)[statusItem view] setImage:statusImageInverse];
	}
	else {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsInvertScrolling]) {
			[(NSButton *)[statusItem view] setImage:statusImage];
		}
		else {
			[(NSButton *)[statusItem view] setImage:statusImageDisabled];
		}					
	}
	[[statusItem view] setNeedsDisplay:YES];
}

#define FRAMES (40.0f)
- (id)init
{
	self = [super init];
	
	// Loadup status icons.
	const NSSize iconSize=NSMakeSize(14, 17);
	NSImage *original=[NSImage imageNamed:@"ScrollInverterStatus"];
	
	statusImage=[original copyWithSize:iconSize];
	statusImageInverse=[original copyWithSize:iconSize colorTo:[NSColor whiteColor]];
	// gray icon needs coloring before sizing due to aliasing effects
	NSImage *grayTemp=[original copyWithSize:[original size] colorTo:[NSColor colorWithDeviceRed:0.6 green:0.6 blue:0.6 alpha: 1.0]]; 
	statusImageDisabled=[grayTemp copyWithSize:iconSize];	
	
	// build status item
	float width = iconSize.width+4;
    float height = [[NSStatusBar systemStatusBar] thickness];
    NSRect viewFrame = NSMakeRect(0, 0, width, height);
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:width] retain];
    [statusItem setView:[[DCStatusItemView alloc] initWithFrame:viewFrame controller:self]];
	[self updateItems];
	[[statusItem view] display];
	
	[self observePrefsKey:PrefsInvertScrolling];
	
	canOpenMenu=YES;
	
	return self;
}

- (void)menuWillOpen:(NSMenu *)menu
{
	menuIsOpen=YES;
	canOpenMenu=NO;
	[self updateItems];
}

- (void)allowOpen
{
	canOpenMenu=YES;
}

- (void)menuDidClose:(NSMenu *)menu
{
	menuIsOpen=NO;
	[self updateItems];	
	[self performSelector:@selector(allowOpen) withObject:nil afterDelay:0.3];
}

- (void)attachMenu:(NSMenu *)menu
{
	theMenu=menu;
	[menu setDelegate:self];
}

- (void)showAttachedMenu:(BOOL)force
{
	if (force || (!menuIsOpen && canOpenMenu)) {
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self updateItems];
}

@end
