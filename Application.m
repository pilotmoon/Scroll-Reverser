// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// (c) Nicholas Moore. Licensed under Apache License v2.0 (see LICENSE).

#import "Application.h"
#import "AppDelegate.h"

@implementation Application

- (NSNumber*)enabled {
    BOOL enabled=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling];
    return @(enabled);
}

- (void)setEnabled:(NSNumber*)state {
    [[NSUserDefaults standardUserDefaults] setBool:[state boolValue] forKey:PrefsReverseScrolling];
}

@end
