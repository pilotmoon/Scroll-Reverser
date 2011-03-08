//
//  DCWelcomeWindowController.m
//  dc
//
//  Created by Work on 18/06/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "DCWelcomeWindowController.h"
#import "DCBubbleWindow.h"

@implementation DCWelcomeWindowController

- (id) init {
    self = [super init];
	if (self)
	{
		window=[[DCBubbleWindow alloc] init];
		[window setLevel:NSFloatingWindowLevel];	
		[window setPointObj:[NSApp delegate] sel:@selector(bubblePoint)];
		
		nib=[[NSNib alloc] initWithNibNamed:@"Welcome" bundle:nil];
		if (![nib instantiateNibWithOwner:self topLevelObjects:0]) return nil;
		[startupSetting setState:NSOffState];
	}
	return self;
}

- (void)doWelcome
{
	NSLog(@"wv %@", welcomeView);
	[window setView:welcomeView];
	[window center];
	[window makeKeyAndOrderFront:self];		
	[NSApp activateIgnoringOtherApps:YES];
	NSLog(@"hmmm");
}

- (IBAction)handleButton:(id)sender
{
	switch ([sender tag]) {
		case 0:
			[window close];
			break;
			
		default:
			break;
	}
}

@end
