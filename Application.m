//
//  Application.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 09/12/2014.
//
//

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
