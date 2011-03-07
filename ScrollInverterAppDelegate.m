//
//  ScrollInverterAppDelegate.m
//  Scroll Inverter
//
//  Created by Work on 07/03/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "ScrollInverterAppDelegate.h"
#import "MouseTap.h"

@implementation ScrollInverterAppDelegate

- (id)init
{
	self=[super init];
	if (self) {
		tap=[[MouseTap alloc] init];
		tap.inverting=YES;
	}
	return self;
}


- (void)awakeFromNib
{
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setTitle:@"SI"];
	[statusItem setHighlightMode:YES];	
	[statusItem setMenu:statusMenu];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[tap start];
}

@end
