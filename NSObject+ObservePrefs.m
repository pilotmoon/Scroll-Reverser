// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// (c) Nicholas Moore. Licensed under Apache License v2.0 (see LICENSE).

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
