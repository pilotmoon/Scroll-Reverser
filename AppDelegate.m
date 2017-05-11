// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "AppDelegate.h"
#import "StatusItemController.h"
#import "LoginItemsController.h"
#import "MouseTap.h"
#import "WelcomeWindowController.h"
#import "PrefsWindowController.h"
#import "DebugWindowController.h"
#import "TestWindowController.h"
#import "TapLogger.h"
#import <Sparkle/SUUpdater.h>

NSString *const PrefsReverseScrolling=@"InvertScrollingOn";
NSString *const PrefsReverseHorizontal=@"ReverseX";
NSString *const PrefsReverseVertical=@"ReverseY";
NSString *const PrefsReverseTrackpad=@"ReverseTrackpad";
NSString *const PrefsReverseMouse=@"ReverseMouse";
NSString *const PrefsReverseTablet=@"ReverseTablet";
NSString *const PrefsHasRunBefore=@"HasRunBefore";
NSString *const PrefsHideIcon=@"HideIcon";

void *kContextHideIcon=&kContextHideIcon;
void *kContextReverseScrolling=&kContextReverseScrolling;

@implementation AppDelegate

+ (void)initialize
{
	if ([self class]==[AppDelegate class])
    {
		[[NSUserDefaults standardUserDefaults] registerDefaults:@{
            PrefsReverseScrolling: @(YES),
            PrefsReverseHorizontal: @(NO),
            PrefsReverseVertical: @(YES),
            PrefsReverseTrackpad: @(YES),
            PrefsReverseMouse: @(YES),
            PrefsReverseTablet: @(YES),
            LoggerMaxEntries: @(50000),
        }];
	}
}

- (void)relaunch
{
    // based on https://gist.github.com/cdfmr/2204627
    const int processID=[[NSProcessInfo processInfo] processIdentifier];
    NSString *const command=[NSString stringWithFormat:@"logger \"waiting for pid %1$d\"; while kill -0 %1$d >/dev/null 2>&1; do sleep 0.01; done; logger \"restarting Scroll Reverser\"; open \"%2$@\"", processID, [[NSBundle mainBundle] bundlePath]];
    NSLog(@"[%@]", command);
    NSTask *const task=[[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:@[@"-c", command]];
    [task launch];
    [NSApp terminate:nil];
}

- (BOOL)alreadyRunning
{
    const BOOL alreadyRunning=^BOOL {
        for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications]) {
            if (![app isEqual:[NSRunningApplication currentApplication]]) {
                if ([app.bundleIdentifier isEqualToString:[NSRunningApplication currentApplication].bundleIdentifier]) {
                    return YES;
                }
            }
        }
        return NO;
    }();
    
    if (alreadyRunning) {
        [[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"%@ is already running.", nil), self.appName]
                         defaultButton:NSLocalizedString(@"Quit", nil)
                       alternateButton:nil
                           otherButton:nil
             informativeTextWithFormat:NSLocalizedString(@"%@ cannot start while another copy is running.", nil), self.appName] runModal];
    }
    
    return alreadyRunning;
}

- (NSURL *)feedURL
{
    if ([[self.appVersion componentsSeparatedByString:@"-"] count]>1) { // if version string has a dash, it's a beta
        return [NSURL URLWithString:@"https://rink.hockeyapp.net/api/2/apps/4eb70fe73a84cb8cd252855a6d7b1bb3"];
    }
    else {
        return [NSURL URLWithString:@"https://softwareupdate.pilotmoon.com/update/scrollreverser/appcast.xml"];
    }
}

- (id)init
{
    self=[super init];
    if (self) {
        if([self alreadyRunning]) {
            quitting=YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSApp terminate:nil];
            });
        }
        else {
            tap=[[MouseTap alloc] init];
            
            loginItemsController=[[LoginItemsController alloc] init];
            statusController=[[StatusItemController alloc] init];
            statusController.statusItemDelegate=self;
            statusController.visible=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon];
            [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PrefsHideIcon options:0 context:kContextHideIcon];
            
            [[SUUpdater sharedUpdater] setDelegate:self];
            [[SUUpdater sharedUpdater] setFeedURL:[self feedURL]];
        }
    }
    return self;
}

- (void)dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (void)awakeFromNib
{
    if(quitting) return;
	[statusController attachMenu:statusMenu];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if(quitting) return;
    
    [NSApp setMainMenu:self.theMainMenu];
    
	const BOOL first=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHasRunBefore];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsHasRunBefore];
	if(first) {
        welcomeWindowController=[[WelcomeWindowController alloc] initWithWindowNibName:@"WelcomeWindow"];
        [welcomeWindowController showWindow:self];
	}
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(appDidWake:) name:NSWorkspaceDidWakeNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(appWillSleep:) name:NSWorkspaceWillSleepNotification object:nil];
    
    NSLog(@"Scroll Reverser ready. Option-click the Scroll Reverser menu bar icon to show the debug console.");
    
    // this will kick off the mouse tap if already enables
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PrefsReverseScrolling options:NSKeyValueObservingOptionInitial context:kContextReverseScrolling];
}

- (void)appDidWake:(NSNotification *)note
{
    [self logAppEvent:@"OS woke from sleep"];
    NSLog(@"Scroll Reverser will relaunch itself because the OS woke from sleep.");
    [self relaunch];
}

- (void)appWillSleep:(NSNotification *)note
{
    [self logAppEvent:@"OS is going to sleep"];
}

- (NSString *)settingsSummary
{
    NSString *(^yn)(NSString *, BOOL) = ^(NSString *label, BOOL state) {
        return [NSString stringWithFormat:@"[%@ %@]", label, state?@"yes":@"no"];
    };
    NSString *temp=yn(@"on", [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling]);
    temp=[temp stringByAppendingString:yn(@"v", [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseVertical])];
    temp=[temp stringByAppendingString:yn(@"h", [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseHorizontal])];
    temp=[temp stringByAppendingString:yn(@"trackpad", [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseTrackpad])];
    temp=[temp stringByAppendingString:yn(@"tablet", [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseTablet])];
    temp=[temp stringByAppendingString:yn(@"mouse/other", [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseMouse])];
    return temp;
}

- (void)logAppEvent:(NSString *)str
{
    [logger logMessage:[NSString stringWithFormat:@"%@ %@", str, [self settingsSummary]] special:YES];
}

- (void)toggleReversing
{
    const BOOL state=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling];
    [[NSUserDefaults standardUserDefaults] setBool:!state forKey:PrefsReverseScrolling];
}

- (Logger *)startLogging
{
    if (!logger) {
        logger=[[TapLogger alloc] init];
        tap->logger=logger;
    }
    return logger;
}

- (IBAction)showDebug:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    if(!debugWindowController) {
        debugWindowController=[[DebugWindowController alloc] initWithWindowNibName:@"DebugWindow"];
        debugWindowController.logger=[self startLogging];
    }
    [debugWindowController showWindow:self];
}

- (IBAction)showPrefs:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    if(!prefsWindowController) {
        prefsWindowController=[[PrefsWindowController alloc] initWithWindowNibName:@"PrefsWindow"];
    }
    [prefsWindowController showWindow:self];
}

- (IBAction)showAbout:(id)sender
{
    [prefsWindowController close];
	[NSApp activateIgnoringOtherApps:YES];
    NSDictionary *dict=@{@"ApplicationName": @"Scroll Reverser"};
    [NSApp orderFrontStandardAboutPanelWithOptions:dict];
}

- (IBAction)showTestWindow:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    if(!testWindowController) {
        testWindowController=[[TestWindowController alloc] initWithWindowNibName:@"TestWindow"];
    }
    [testWindowController showWindow:self];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsHideIcon];
    [statusController openMenu];
	return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context==kContextHideIcon) {
        BOOL wasVisible=statusController.visible;
        statusController.visible=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon];;
        if (wasVisible&&!statusController.visible)
        {
            [NSApp activateIgnoringOtherApps:YES];
            NSAlert *alert=[NSAlert alertWithMessageText:NSLocalizedString(@"Status Icon Hidden",nil)
                                           defaultButton:NSLocalizedString(@"OK",nil)
                                         alternateButton:nil
                                             otherButton:nil
                               informativeTextWithFormat:NSLocalizedString(@"MENU_HIDDEN_TEXT", @"text shown when the menu bar icon is hidden")];
            [alert runModal];
        }
    }
    else if (context==kContextReverseScrolling) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling]) {
            statusController.enabled=YES;
            [tap start];
        }
        else {
            statusController.enabled=NO;
            [tap stop];
        }
    }
}

#pragma mark Status item handling

- (void)statusItemClicked
{
    // do nothing
}

- (void)statusItemRightClicked
{
    [self toggleReversing];
}

- (void)statusItemAltClicked
{
    [self showDebug:self];
}

#pragma mark Sparkle delegate methods

- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater sendingSystemProfile:(BOOL)sendingProfile
{
    NSLog(@"Checking for updates at %@", [updater feedURL]);
    return [NSArray array];
}

#pragma mark App info

- (NSString *)appName {
    return @"Scroll Reverser";
}

- (NSString *)appVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)appCredit {
    return @"by Nick Moore";
}

- (NSURL *)appLink {
    return [NSURL URLWithString:@"https://pilotmoon.com/link/scrollreverser"];
}

- (NSString *)appDisplayLink {
    return @"pilotmoon.com/scrollreverser";
}

#pragma mark Strings

- (NSString *)menuStringReverseScrolling {
	return NSLocalizedString(@"Reverse Scrolling", nil);
}
- (NSString *)menuStringPreferences {
    return [NSLocalizedString(@"Preferences", nil) stringByAppendingString:@"..."];
}
- (NSString *)menuStringQuit {
    return NSLocalizedString(@"Quit Scroll Reverser", nil);
}

@end

