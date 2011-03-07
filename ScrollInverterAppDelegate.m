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

@synthesize window;

- (id)init
{
	self=[super init];
	if (self) {
		tap=[[MouseTap alloc] init];
	}
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[tap start];
}

@end
