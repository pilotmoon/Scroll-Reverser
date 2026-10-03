// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

// NSApp holds its delegate weakly, so keep a strong reference for the life of the app.
static AppDelegate *appDelegate;

int main(int argc, char *argv[])
{
    @autoreleasepool {
        // Create the delegate before NSApplicationMain, so that its init runs before launch.
        appDelegate=[[AppDelegate alloc] init];
        [NSApplication sharedApplication].delegate=appDelegate;
    }
    return NSApplicationMain(argc,  (const char **) argv);
}
