//
//  PermissionsManager.m
//  Scroll Reverser
//
//  Created by Nicholas Moore on 21/11/2019.
//

#import "PermissionsManager.h"

NSString *const PermissionsManagerKeyAccessibilityEnabled=@"accessibilityEnabled";
NSString *const PermissionsManagerKeyHasAllRequiredPermissions=@"hasAllRequiredPermissions";

static NSString *const PrefsHasRequestedAccessibilityPermission=@"HasRequestedAccessibilityPermission";

@interface PermissionsManager ()
@property (getter=isAccessibilityEnabled) BOOL accessibilityEnabled;
@property NSTimer *refreshTimer;
@property NSDate *refreshStarted;
@end

@implementation PermissionsManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self checkState];
        // refresh on user activity
        const NSEventMask mask=NSEventMaskLeftMouseDown;
        [NSEvent addGlobalMonitorForEventsMatchingMask:mask handler:^(NSEvent *event) {
            [self refresh];
        }];
        [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
            [self refresh];
            return event;
        }];
    }
    return self;
}

# pragma mark Private Methods

- (BOOL)checkAccessibilityWithPrompt:(BOOL)prompt
{
    // this is a 10.9 API but is only needed on 10.14.
    // with no prompt, this check is very fast. otherwise it blocks.
    NSDictionary *const options=@{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @(prompt)};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

+ (NSSet *)keyPathsForValuesAffectingHasAllRequiredPermissions
{
    return [NSSet setWithObject:PermissionsManagerKeyAccessibilityEnabled];
}

- (void)checkState
{
    BOOL axState=[self checkAccessibilityWithPrompt:NO];
    if(axState!=self.accessibilityEnabled) {
        self.accessibilityEnabled=axState;
    }
    NSLog(@"permissions: ax %@", @(axState));
}

#pragma mark Public Interface

/* Every time this is called, a repeat timer will repeatedly poll. */
- (void)refresh
{
    // always do timer stuff on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        self.refreshStarted=[NSDate date];
        if (!self.refreshTimer.valid) {
            self.refreshTimer=[NSTimer scheduledTimerWithTimeInterval:0.333 repeats:YES block:^(NSTimer * _Nonnull timer) {
                [self checkState];
                if ([[NSDate date] timeIntervalSinceDate:self.refreshStarted]>2.5) {
                    [self.refreshTimer invalidate];
                    self.refreshTimer=nil;
                }
            }];
        }
    });
}

- (BOOL)hasAllRequiredPermissions
{
    BOOL result=YES;
    if (self.accessibilityRequired && !self.accessibilityEnabled) {
        NSLog(@"missing required accessibility permission");
        result=NO;
    }
    return result;
}

+ (NSURL *)securitySettingsUrlForKey:(NSString *)key
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"x-apple.systempreferences:com.apple.preference.security?%@", key]];
}
- (void)requestAccessibilityPermission
{
    [self willChangeValueForKey:@"accessibilityRequested"];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsHasRequestedAccessibilityPermission];
    [self didChangeValueForKey:@"accessibilityRequested"];
    [self checkAccessibilityWithPrompt:YES];

}

- (void)openAccessibilityPrefs
{
    [[NSWorkspace sharedWorkspace] openURL:[[self class] securitySettingsUrlForKey:@"Privacy_Accessibility"]];
}

// Accessibility permission is needed on Mojave and above
- (BOOL)isAccessibilityRequired
{
    if (@available(macOS 10.14, *)) {
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)isAccessibilityRequested
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrefsHasRequestedAccessibilityPermission];
}


@end
