//
//  NSObject+ObservePrefs.m
//  dc
//
//  Created by Work on 11/06/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import "NSObject+ObservePrefs.h"


@implementation NSObject (ObservePrefs)

- (void)observePrefsKey:(NSString *)key
{
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
															  forKeyPath:[@"values." stringByAppendingString:key]
																 options:0
																 context:nil];
}

@end
