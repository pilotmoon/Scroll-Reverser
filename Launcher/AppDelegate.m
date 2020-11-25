//
//  AppDelegate.m
//  Launcher
//
//  Created by Nicholas Moore on 25/11/2020.
//

#import "AppDelegate.h"

@implementation AppDelegate

static NSString *const _bundleIdentifier=@"com.pilotmoon.scroll-reverser";
static NSString *const _launchUrlString=@"x-scroll-reverser://launch";

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // check if already running
    if ([[NSRunningApplication runningApplicationsWithBundleIdentifier:_bundleIdentifier] count]==0)
    {
        // not running, so launch via url scheme
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:_launchUrlString]];
    }

    // quit in 1 second
    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:1];
}


@end
