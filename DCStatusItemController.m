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

static NSSize _iconSize;

@implementation DCStatusItemController
@synthesize statusItem, menuIsOpen;

- (void)updateItems
{
	NSLog(@"update");
	if (menuIsOpen) {
		[(NSButton *)[statusItem view] setImage:statusImageInverse];
	}
	else {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling]) {
			[(NSButton *)[statusItem view] setImage:statusImage];
		}
		else {
			[(NSButton *)[statusItem view] setImage:statusImageDisabled];
		}					
	}
	[[statusItem view] setNeedsDisplay:YES];
}

- (void)addStatusIcon
{
	if (!statusItem) {
		float width = _iconSize.width+4;
		float height = [[NSStatusBar systemStatusBar] thickness];
		NSRect viewFrame = NSMakeRect(0, 0, width, height);
		statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:width] retain];
		[statusItem setView:[[[DCStatusItemView alloc] initWithFrame:viewFrame controller:self] autorelease]];
		[self updateItems];
		[[statusItem view] display];			
	}
}

- (void)removeStatusIcon
{
	if (statusItem) {
		[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
		[statusItem release];
		statusItem=nil;
	}
}

- (void)displayStatusIcon
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon]) {
		[self removeStatusIcon];
	}
	else {
		[self addStatusIcon];
	}
}

#define FRAMES (40.0f)
- (id)init
{
	self = [super init];
	
	_iconSize=NSMakeSize(14, 17);
	
	// Loadup status icons.
	NSImage *original=[NSImage imageNamed:@"ScrollInverterStatus"];
	
	statusImage=[original copyWithSize:_iconSize];
	statusImageInverse=[original copyWithSize:_iconSize colorTo:[NSColor whiteColor]];
	// gray icon needs coloring before sizing due to aliasing effects
	NSImage *grayTemp=[[original copyWithSize:[original size] colorTo:[NSColor colorWithDeviceRed:0.6 green:0.6 blue:0.6 alpha: 1.0]] autorelease]; 
	statusImageDisabled=[grayTemp copyWithSize:_iconSize];	
	
	[self displayStatusIcon];
	
	[self observePrefsKey:PrefsReverseScrolling];
	[self observePrefsKey:PrefsHideIcon];
	
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
	[self displayStatusIcon];
	[self updateItems];
}

@end
