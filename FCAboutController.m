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
	
	linkButton1.backgroundColor=[NSColor colorWithDeviceRed:0.34 green:0.69 blue:0.78 alpha:1.0]; 
	linkButton1.borderColor=nil;
	linkButton2.backgroundColor=[NSColor colorWithDeviceRed:0.34 green:0.69 blue:0.78 alpha:1.0];
	linkButton2.borderColor=nil;	
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

- (NSString *)productUrl
{
	return @"http://pilotmoon.com/scrollreverser";
}

- (NSString *)versionStatement
{
	NSString *base=@"v%@";
	return [NSString stringWithFormat:base, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
}

- (NSString *)linkButton1Text
{
	return NSLocalizedString(@"More Apps", @"Button which takes the user to see more apps from Pilotmoon Software on the web site");
}

- (IBAction)linkButton1:(id)sender
{
	[self closeAboutWindow:self];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.pilotmoon.com/link/scrollreverser/more"]];
}

- (NSString *)linkButton2Text
{
	return NSLocalizedString(@"Tell a Friend", nil);
}

- (IBAction)linkButton2:(id)sender
{
	[self closeAboutWindow:self];
	NSString *addr=@"";
	NSString *subj=NSLocalizedString(@"Check out this Mac app: Scroll Reverser", nil);
	NSString *body=[NSString stringWithFormat:NSLocalizedString(@"Scroll Reverser for Mac, at %@", @"%@ is the url of scroll reverser (usually http://pilotmoon.com/scrollreverser)"), [self productUrl]];
	NSString *urls=[[NSString stringWithFormat:@"mailto:%@?subject=%@&body=%@", addr, subj, body, nil] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urls]];
	
}

@end
