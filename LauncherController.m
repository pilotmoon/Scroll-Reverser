//
//  LauncherController.m
//  Scroll Reverser
//
//  Created by Nicholas Moore on 25/11/2020.
//

#import "LauncherController.h"
#import <ServiceManagement/ServiceManagement.h>

static NSString *const kPrefsStartAtLogin=@"StartAtLogin";
static NSString *const kLauncherBundleID=@"com.pilotmoon.scroll-reverser.launcher";

@implementation LauncherController

+ (BOOL)loginItemState
{
    // though deprecated, this is explicitly allowed for this purpose (see header)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray *const jobDicts = (__bridge_transfer NSArray *)SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
#pragma clang diagnostic pop

    for (NSDictionary *job in jobDicts) {
        if ([kLauncherBundleID isEqualToString:job[@"Label"]]) {
            return [job[@"OnDemand"] boolValue];
        }
    }
    return NO;
}

+ (void)setLoginItemState:(BOOL)state
{
    if (SMLoginItemSetEnabled((__bridge CFStringRef)kLauncherBundleID, state)) {
        NSLog(@"SMLoginItemSetEnabled setting %d succeeded.", state);
    }
    else {
        NSLog(@"SMLoginItemSetEnabled setting %d failed.", state);
    }
}

+ (void)initialize
{
    if (self==[LauncherController class]) {
        const BOOL state=[[NSUserDefaults standardUserDefaults] boolForKey:kPrefsStartAtLogin];
        NSLog(@"Launcher state is %@; prefs state is %@", @([self loginItemState]), @(state));
        [self setLoginItemState:state];
    }
}

- (void)setStartAtLogin:(BOOL)state
{
    // as well as installing the login item, save state to prefs in case the login item gets "forgotten"
    [[NSUserDefaults standardUserDefaults] setBool:state forKey:kPrefsStartAtLogin];
    [[self class] setLoginItemState:state];
}

- (BOOL)startAtLogin
{
    return [[self class] loginItemState];
}

@end
