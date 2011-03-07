//
//  FCLinkView.m
//  fc
//
//  Created by Work on 25/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "FCLinkView.h"
#import "DCLinks.h"

@implementation FCLinkView

- (void)mouseUp:(NSEvent *)theEvent
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.pilotmoon.com/link/scrollinverter/site"]];
}
@end
