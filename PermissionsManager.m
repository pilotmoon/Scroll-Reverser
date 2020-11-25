//
//  PermissionsManager.m
//  Scroll Reverser
//
//  Created by Nicholas Moore on 21/11/2019.
//

#import "PermissionsManager.h"
#import <IOKit/hidsystem/IOHIDLib.h>

NSString *const PermissionsManagerKeyAccessibilityEnabled=@"accessibilityEnabled";
NSString *const PermissionsManagerKeyInputMonitoringEnabled=@"inputMonitoringEnabled";
NSString *const PermissionsManagerKeyHasAllRequiredPermissions=@"hasAllRequiredPermissions";

static NSString *const PrefsHasRequestedInputMonitoringPermission=@"HasRequestedInputMonitoringPermission";
static NSString *const PrefsHasRequestedAccessibilityPermission=@"HasRequestedAccessibilityPermission";

@interface PermissionsManager ()
@property (getter=isAccessibilityEnabled) BOOL accessibilityEnabled;
@property (getter=isInputMonitoringEnabled) BOOL inputMonitoringEnabled;
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

- (BOOL)checkInputMonitoringWithPrompt:(BOOL)prompt
{
    if (@available(macOS 10.15, *)) {
        static const IOHIDRequestType accessType=kIOHIDRequestTypeListenEvent;
        if (prompt) {
            // this will block
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                IOHIDRequestAccess(accessType);
            });
            return NO;
        }
        else {
            // this check is very fast
            return kIOHIDAccessTypeGranted==IOHIDCheckAccess(accessType);
        }
    }
    else {
        return YES;
    }
}

+ (NSSet *)keyPathsForValuesAffectingHasAllRequiredPermissions
{
    return [NSSet setWithArray:@[PermissionsManagerKeyAccessibilityEnabled, PermissionsManagerKeyInputMonitoringEnabled]];
}

- (void)checkState
{
    BOOL axState=[self checkAccessibilityWithPrompt:NO];
    if(axState!=self.accessibilityEnabled) {
        self.accessibilityEnabled=axState;
    }
    BOOL imState=[self checkInputMonitoringWithPrompt:NO];
    if(imState!=self.inputMonitoringEnabled) {
        self.inputMonitoringEnabled=imState;
    }
    NSLog(@"permissions: ax %@, im %@", @(axState), @(imState));
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
    if (self.inputMonitoringRequired && !self.inputMonitoringEnabled) {
        NSLog(@"missing required input monitoring permission");
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

- (void)requestInputMonitoringPermission
{
    [self willChangeValueForKey:@"inputMonitoringRequested"];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsHasRequestedInputMonitoringPermission];
    [self didChangeValueForKey:@"inputMonitoringRequested"];
    [self checkInputMonitoringWithPrompt:YES];
}

- (void)openAccessibilityPrefs
{
    [[NSWorkspace sharedWorkspace] openURL:[[self class] securitySettingsUrlForKey:@"Privacy_Accessibility"]];
}

- (void)openInputMonitoringPrefs
{
    [[NSWorkspace sharedWorkspace] openURL:[[self class] securitySettingsUrlForKey:@"Privacy_ListenEvent"]];
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

 // Input Monitoring permission is needed on Catalina and above
- (BOOL)isInputMonitoringRequired
{
    if (@available(macOS 10.15, *)) {
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

// macos only lets an app request this ONCE EVER. so we remember if we requested it, and
// thereafter can offer to open the prefpane instead
- (BOOL)isInputMonitoringRequested
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:PrefsHasRequestedInputMonitoringPermission];
}


@end
