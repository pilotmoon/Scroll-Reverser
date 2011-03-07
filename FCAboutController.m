//
//  FCAboutController.m
//  fc
//
//  Created by Work on 25/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "FCAboutController.h"
#import "DCAboutWindow.h"


@implementation FCAboutController


- (id)init {
	nib=[[NSNib alloc] initWithNibNamed:@"About" bundle:nil];
	if (![nib instantiateNibWithOwner:self topLevelObjects:0]) return nil;

	
	
	self.window=[[DCAboutWindow alloc] initWithContentRect:[contents frame]
											styleMask:NSBorderlessWindowMask
											  backing:NSBackingStoreBuffered
												defer:NO];
	
	[[self window] setHasShadow:YES];
	[[self window] setContentView:contents];
	[[self window] setContentSize:[contents frame].size];
	[[self window] center];
	[[self window] setLevel:NSFloatingWindowLevel];
	[[self window] setOpaque:NO];
	[[self window] setBackgroundColor:[NSColor clearColor]];
	[[self window] setMovableByWindowBackground:YES];
	
	reviewButton.backgroundColor=[NSColor colorWithDeviceRed:0.34 green:0.69 blue:0.78 alpha:1.0]; 
	reviewButton.borderColor=nil;
	friendButton.backgroundColor=[NSColor colorWithDeviceRed:0.34 green:0.69 blue:0.78 alpha:1.0];
	friendButton.borderColor=nil;	
	return self;
}

- (void)showWindow:(id)sender
{
	[[self window] center];
	[NSApp activateIgnoringOtherApps:YES];
	[[self window] makeKeyAndOrderFront:self];
}

- (IBAction)closeAboutWindow:(id)sender
{
	[[self window] close];
}

- (NSString *)copyrightStatement
{
	return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSHumanReadableCopyright"];
}

- (NSString *)versionStatement
{
	NSString *base=@"v%@";
	return [NSString stringWithFormat:base, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
}

- (NSString *)reviewButtonText
{
	return @"More Apps";
}

- (NSString *)webLink
{
	return @"http://dwellclick.com";
}

- (IBAction)writeAReview:(id)sender
{
	[self closeAboutWindow:self];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.pilotmoon.com/link/scrollinverter/site"]];
}

@end
