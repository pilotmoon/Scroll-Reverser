//
//  DCLinks.m
//  dc
//
//  Created by Work on 05/07/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "DCLinks.h"

@implementation DCLinks

#define ID_CHARS 6

+ (void)openLinkWithStandardQuery:(NSString *)urlString params:(NSDictionary *)params
{
	NSMutableDictionary *query=[DCLinks standardQuery];
	if (params) {
		[query addEntriesFromDictionary:params];
	}
	DLog(@"query %@", query);
	// build string
	NSMutableString *queryString=[NSMutableString string];
	NSString *pattern=@"?%@=%@";
	for(NSString *key in [[query allKeys] sortedArrayUsingSelector:@selector(compare:)])
	{
		[queryString appendString:[NSString stringWithFormat:pattern, key, [query objectForKey:key]]];
		pattern=@"&%@=%@";			
	}
	
	// open url
	NSURL *url=[NSURL URLWithString:queryString relativeToURL:[NSURL URLWithString:urlString]];
	[[NSWorkspace sharedWorkspace] openURL:url];
	DLog(@"opened %@", url);
}


+ (void)openBetaLink:(id)sender
{
	[self openLinkWithStandardQuery:@"http://www.pilotmoon.com/link/dwellclick/beta" params:nil];
}

+ (void)openBuyLink:(id)sender
{
#ifdef DC_LICENSING
	NSString *src=@"Def";
	if ([sender class]==[DCMainMenuController class]) {
		src = @"Menu";
	}
	else if ([sender class]==[DCReminderWindowController class]) {
		src = @"Rem";
	}
	else if ([sender class]==[DCPrefsSoftwareController class]) {
		src = @"Prefs";
	}
	NSDictionary *extraParams=[NSDictionary dictionaryWithObjectsAndKeys:
							   src, @"src",
							   nil];
	[self openLinkWithStandardQuery:@"http://www.pilotmoon.com/link/dwellclick/buy" params:extraParams];
#endif
}

+ (void)openSiteLink:(id)sender
{
	[self openLinkWithStandardQuery:@"http://www.pilotmoon.com/link/dwellclick/site" params:nil];
}

+ (void)openTutorialLink:(id)sender
{
	BOOL touchpad=DCTouchMonitorMaxFingers>0;
	NSString *addr=[NSString stringWithFormat:@"http://www.pilotmoon.com/link/dwellclick/tutorial/%@", touchpad?@"touch":@"mouse"];
	[self openLinkWithStandardQuery:addr params:nil];
}

+ (void)openHelpLink:(id)sender
{
	[self openLinkWithStandardQuery:@"http://www.pilotmoon.com/link/dwellclick/help" params:nil];
}

+ (void)openHelpTopic:(NSString *)topic
{
	[self openLinkWithStandardQuery:[NSString stringWithFormat:@"http://www.pilotmoon.com/link/dwellclick/help/topic/%@", topic] params:nil];
}

+ (void)openReviewLink:(id)sender
{
#ifdef DC_APPSTORE
	[self openLinkWithStandardQuery:@"http://www.pilotmoon.com/link/dwellclick/review-appstore" params:nil];
#else
	[self openLinkWithStandardQuery:@"http://www.pilotmoon.com/link/dwellclick/review-site" params:nil];
#endif
}

+ (void)openTagLink:(id)sender
{
	NSInteger tag=[sender tag];
	switch (tag) {
		case 0:
			[self openLinkWithStandardQuery:@"http://www.pilotmoon.com/link/scrollinverter/site" params:nil];
			break;
		default:
			break;
	}
}

}

@end
