//
//  LauncherController.m
//  Scroll Reverser
//
//  Created by Nicholas Moore on 25/11/2020.
//

#import "LauncherController.h"
#import <ServiceManagement/ServiceManagement.h>

static NSString *const kPrefsStartAtLogin=@"StartAtLogin";

@interface LauncherController ()
@property LSSharedFileListRef loginItems;
@end

@implementation LauncherController

- (instancetype)init
{
    self=[super init];
    if (self) {
        [self setFromPrefs];
    }
    return self;
}

// older versions used an embedded xpc launcher and also saved the state in prefs as a backup.
// here we "one shot" migrate the state from the old prefs to the new method.
- (void)setFromPrefs
{
    const BOOL state=[[NSUserDefaults standardUserDefaults] boolForKey:kPrefsStartAtLogin];
    if (state) {
        [self setStartAtLogin:YES];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPrefsStartAtLogin];
    }
}

- (void)setStartAtLogin:(BOOL)state
{
    if (@available(macOS 13.0, *)) {
        [self willChangeValueForKey:@"startAtLogin"];
        NSError *error=nil;
        if (state) {
            if (SMAppService.mainAppService.status==SMAppServiceStatusEnabled) {
                [SMAppService.mainAppService unregisterAndReturnError:&error];
            }
            [SMAppService.mainAppService registerAndReturnError:&error];
        } else {
            [SMAppService.mainAppService unregisterAndReturnError:&error];
        }
        if (error) {
            NSLog(@"Error setting startAtLogin to %@: %@", @(state), error);
        }
        [self didChangeValueForKey:@"startAtLogin"];
    }
}

- (BOOL)startAtLogin
{
    if (@available(macOS 13.0, *)) {
        return SMAppService.mainAppService.status==SMAppServiceStatusEnabled;
    } else {
        return NO;
    }
}

@end
