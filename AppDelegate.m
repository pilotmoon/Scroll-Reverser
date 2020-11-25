// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "AppDelegate.h"
#import "StatusItemController.h"
#import "MouseTap.h"
#import "WelcomeWindowController.h"
#import "PrefsWindowController.h"
#import "DebugWindowController.h"
#import "TestWindowController.h"
#import "TapLogger.h"

NSString *const PrefsReverseScrolling=@"InvertScrollingOn";
NSString *const PrefsReverseHorizontal=@"ReverseX";
NSString *const PrefsReverseVertical=@"ReverseY";
NSString *const PrefsReverseTrackpad=@"ReverseTrackpad";
NSString *const PrefsReverseMouse=@"ReverseMouse";
NSString *const PrefsHasRunBefore=@"HasRunBefore";
NSString *const PrefsHideIcon=@"HideIcon";
NSString *const PrefsBetaUpdates=@"BetaUpdates";
NSString *const PrefsAppcastOverrideURL=@"AppcastOverrideURL";

static void *_contextHideIcon=&_contextHideIcon;
static void *_contextEnabled=&_contextEnabled;
static void *_contextPermissions=&_contextPermissions;

@interface AppDelegate ()
@property MouseTap *tap;
@property StatusItemController *statusController;
@property WelcomeWindowController *welcomeWindowController;
@property PrefsWindowController *prefsWindowController;
@property DebugWindowController *debugWindowController;
@property TestWindowController *testWindowController;
@property PermissionsManager *permissionsManager;
@property TapLogger *logger;
@end

@implementation AppDelegate

// note that there is a third category of build, "Development" (see BuildScripts)
+ (BOOL)appIsProductionBuild {
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"PilotmoonReleaseChannel"] isEqualToString:@"Production"];
}
+ (BOOL)appIsBetaBuild {
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"PilotmoonReleaseChannel"] isEqualToString:@"Beta"];
}

+ (NSURL *)sparkleFeedURL
{
    NSString *urlString=[[NSUserDefaults standardUserDefaults] stringForKey:PrefsAppcastOverrideURL];
    if (!urlString) {
        if([self appIsProductionBuild]||[self appIsBetaBuild])
        {
            urlString=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsBetaUpdates] ?
                 @"https://softwareupdate.pilotmoon.com/update/scrollreverser/appcast-beta.xml":
                 @"https://softwareupdate.pilotmoon.com/update/scrollreverser/appcast.xml";
        }
    }
    return [NSURL URLWithString:urlString?urlString:@"https://localhost/"];
}

// There can be only one scroll reverser
+ (void)terminateOthers
{
    NSRunningApplication *app=nil;
    for (app in [[NSWorkspace sharedWorkspace] runningApplications]) {
        if (![app isEqual:[NSRunningApplication currentApplication]]) {
            if ([[app.bundleIdentifier lowercaseString] isEqualToString:[[NSRunningApplication currentApplication].bundleIdentifier lowercaseString]]) {
                [app terminate];
            }
        }
    }
}

/* Quickly and quetly quit and relaunch our own process. This is called on wake from sleep as a
 workaround for a macOS bug whereby the OS stops sending calling our event taps after sleep.
 */
- (void)relaunch
{
    [self logAppEvent:@"Scroll Reverser will relaunch"];

    // asynchronously launch a new instance
    NSError *error=nil;
    [[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSBundle mainBundle].bundleURL
                                                  options:NSWorkspaceLaunchAsync|NSWorkspaceLaunchNewInstance
                                            configuration:@{}
                                                    error:&error];

    // terminate self (async for a modicum of cleanliness)
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp terminate:self];
    });
}

+ (void)initialize
{
    if ([self class]==[AppDelegate class])
    {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            PrefsReverseScrolling: @(NO),
            PrefsReverseHorizontal: @(NO),
            PrefsReverseVertical: @(YES),
            PrefsReverseTrackpad: @(YES),
            PrefsReverseMouse: @(YES),
            LoggerMaxEntries: @(50000),
            PrefsBetaUpdates: @([self appIsBetaBuild]),
        }];
    }
}

- (id)init
{
    self=[super init];
    if (self) {
        [[self class] terminateOthers];

        self.tap=[[MouseTap alloc] init];

        self.statusController=[[StatusItemController alloc] init];
        self.statusController.statusItemDelegate=self;
        self.statusController.visible=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon];
        [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PrefsHideIcon options:0 context:_contextHideIcon];

        self.permissionsManager=[[PermissionsManager alloc] init];

        [[SUUpdater sharedUpdater] setDelegate:self];
        [[SUUpdater sharedUpdater] setFeedURL:[[self class] sparkleFeedURL]];
    }
    return self;
}

- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key { // For Applescript handling
    return [key isEqualToString:@"enabled"];
}

- (void)awakeFromNib {
    [self.statusController attachMenu:self.statusMenu];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Even though the app has no visible main menu, we set a minimal menu for keyboard shortcut support.
    // For example, ⌘W to close the prefs window.
    [NSApp setMainMenu:self.theMainMenu];

    // Show the welcome window if the user hasn't run Scroll Reverser before.
	const BOOL first=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHasRunBefore];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsHasRunBefore];
	if(first) {
        self.welcomeWindowController=[[WelcomeWindowController alloc] initWithWindowNibName:@"WelcomeWindow"];
        [self.welcomeWindowController showWindow:self];
	}
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(appDidWake:) name:NSWorkspaceDidWakeNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(appWillSleep:) name:NSWorkspaceWillSleepNotification object:nil];
    
    // Observe permissions updates
    [self.permissionsManager addObserver:self
                              forKeyPath:PermissionsManagerKeyHasAllRequiredPermissions
                                 options:NSKeyValueObservingOptionInitial
                                 context:_contextPermissions];
    [self logAppEvent:@"Scroll Reverser started. Option-click the Scroll Reverser menu bar icon to show the debug console."];

    // We don't bind `enabled` directly to prefs, because of the many dynamic interactions with the setting.
    BOOL enabledInPrefs=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling];
    [self addObserver:self forKeyPath:@"enabled" options:NSKeyValueObservingOptionInitial context:_contextEnabled];
    self.enabled=enabledInPrefs;
}

- (void)appDidWake:(NSNotification *)note
{
    [self logAppEvent:@"OS woke from sleep - will relaunch"];
    [[self class] relaunch];
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
    temp=[temp stringByAppendingString:yn(@"mouse", [[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseMouse])];
    return temp;
}

- (void)logAppEvent:(NSString *)str
{
    NSString *message=[NSString stringWithFormat:@"%@ %@", str, [self settingsSummary]];
    NSLog(@"App event: %@", message);
    [self.logger logMessage:message special:YES];
}

- (void)toggleReversing
{
    const BOOL state=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling];
    [[NSUserDefaults standardUserDefaults] setBool:!state forKey:PrefsReverseScrolling];
}

- (Logger *)startLogging
{
    if (!self.logger) {
        self.logger=[[TapLogger alloc] init];
        self.tap->logger=self.logger;
    }
    return self.logger;
}

- (IBAction)showDebug:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    if(!self.debugWindowController) {
        self.debugWindowController=[[DebugWindowController alloc] initWithWindowNibName:@"DebugWindow"];
        self.debugWindowController.logger=[self startLogging];
    }
    [self.debugWindowController showWindow:self];
}

- (void)showPrefsWithDefaultPane:(BOOL)showDefault
{
    [NSApp activateIgnoringOtherApps:YES];
    if(!self.prefsWindowController) {
        self.prefsWindowController=[[PrefsWindowController alloc] initWithWindowNibName:@"PrefsWindow"];
    }
    if (showDefault) {
        [self.prefsWindowController showPermissionsPane:self];
    }
    [self.prefsWindowController showWindow:self];
}

- (IBAction)showPrefs:(id)sender
{
    [self showPrefsWithDefaultPane:NO];
}

- (IBAction)showAbout:(id)sender
{
    [self.prefsWindowController close];
	[NSApp activateIgnoringOtherApps:YES];
    NSDictionary *dict=@{@"ApplicationName": @"Scroll Reverser"};
    [NSApp orderFrontStandardAboutPanelWithOptions:dict];
}

- (IBAction)showTestWindow:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    if(!self.testWindowController) {
        self.testWindowController=[[TestWindowController alloc] initWithWindowNibName:@"TestWindow"];
    }
    [self.testWindowController showWindow:self];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsHideIcon];
    [self.statusController openMenu];
	return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context==_contextHideIcon) {
        BOOL wasVisible=self.statusController.visible;
        self.statusController.visible=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon];;
        if (wasVisible&&!self.statusController.visible)
        {
            [NSApp activateIgnoringOtherApps:YES];

            NSAlert *alert=[[NSAlert alloc] init];
            alert.messageText=NSLocalizedString(@"Status Icon Hidden",nil);
            alert.informativeText=[NSString stringWithFormat:NSLocalizedString(@"MENU_HIDDEN_TEXT", @"text shown when the menu bar icon is hidden")];
            [alert runModal];
        }
    }
    else if (context==_contextEnabled) {
        self.statusController.enabled=self.enabled;
        [[NSUserDefaults standardUserDefaults] setBool:self.enabled forKey:PrefsReverseScrolling];
    }
    else if (context==_contextPermissions) {
        if(!self.permissionsManager.hasAllRequiredPermissions) {
            self.enabled=NO;
        }
    }
}

#pragma mark Enable/disable

- (void)setEnabled:(BOOL)state
{
    if (state==self.enabled) { // already in this state
        return;
    }

    if ((!state) || self.permissionsManager.hasAllRequiredPermissions) {
        [self logAppEvent:[NSString stringWithFormat:@"Setting enabled state to: %@", @(state)]];
        self.tap.active=state;
    }
    else {
        [self logAppEvent:@"Cannot enable Scroll Reverser; missing required permissions"];
    }

    // in case changing active state fails, force refresh of the triggering button
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self willChangeValueForKey:@"enabled"];
        [self didChangeValueForKey:@"enabled"];
        if (state && (!self.enabled)) { // failed to enable
            [self showPermissionsUI];
        }
    });
}

- (BOOL)isEnabled {
    return self.tap.active;
}

+ (NSSet *)keyPathsForValuesAffectingEnabled {
    return [NSSet setWithObject:@"tap.active"];
}

#pragma mark Status item handling

- (void)statusItemClicked {
    // do nothing
}

- (void)statusItemRightClicked {
    [self toggleReversing];
}

- (void)statusItemAltClicked {
    [self showDebug:self];
}

#pragma mark Permissions

- (void)refreshPermissions {
    [self.permissionsManager refresh];
}

- (void)showPermissionsUI {
    [self showPrefsWithDefaultPane:YES];
}

#pragma mark App info

- (NSString *)appName {
    return @"Scroll Reverser";
}

- (NSString *)appVersion {
    return [NSString stringWithFormat:@"%@ (%@)",
            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
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

- (NSURL *)appPermissionsHelpLink {
    return [NSURL URLWithString:@"https://pilotmoon.com/link/scrollreverser/help/permissions"];
}

#pragma mark Strings

- (NSString *)menuStringReverseScrolling {
	return NSLocalizedString(@"Enable Scroll Reverser", nil);
}
- (NSString *)menuStringPreferences {
    return [NSLocalizedString(@"Preferences", nil) stringByAppendingString:@"..."];
}
- (NSString *)menuStringQuit {
    return NSLocalizedString(@"Quit Scroll Reverser", nil);
}

@end

