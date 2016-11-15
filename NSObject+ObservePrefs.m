// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

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
