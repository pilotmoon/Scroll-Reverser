//
//  DCLinks.h
//  dc
//
//  Created by Work on 05/07/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DCLinks : NSObject {
}

+ (NSMutableDictionary *)standardQuery;
+ (void)openBetaLink:(id)sender;
+ (void)openBuyLink:(id)sender;
+ (void)openTutorialLink:(id)sender;
+ (void)openHelpLink:(id)sender;
+ (void)openSiteLink:(id)sender;
+ (void)openHelpTopic:(NSString *)topic;
+ (void)openReviewLink:(id)sender;
+ (void)openTagLink:(id)sender;
+ (void)tellAFriend;
+ (void)sendFeedback;
@end
