// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

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
