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
#import "MouseMonitor.h"

NSString *const PrefsReverseScrolling=@"InvertScrollingOn";
NSString *const PrefsReverseHorizontal=@"ReverseX";
NSString *const PrefsReverseVertical=@"ReverseY";
NSString *const PrefsReverseTrackpad=@"ReverseTrackpad";
NSString *const PrefsReverseMouse=@"ReverseMouse";
NSString *const PrefsHasRunBefore=@"HasRunBefore";
NSString *const PrefsHideIcon=@"HideIcon";
NSString *const PrefsBetaUpdates=@"BetaUpdates";
NSString *const PrefsAppcastOverrideURL=@"AppcastOverrideURL";
NSString *const PrefsTerminatedWithPrefsWindowOpen=@"TerminatedWithPrefsWindowOpen";
NSString *const PrefsDiscreteScrollStepSize=@"DiscreteScrollStepSize";
NSString *const PrefsShowDiscreteScrollOptions=@"ShowDiscreteScrollOptions";
NSString *const PrefsAutoEnableWithMouse=@"AutoEnableWithMouse";

static void *_contextHideIcon=&_contextHideIcon;
static void *_contextEnabled=&_contextEnabled;
static void *_contextPermissions=&_contextPermissions;
static void *_contextMouseConnected=&_contextMouseConnected;
static void *_contextAutoEnableWithMouse=&_contextAutoEnableWithMouse;

@interface AppDelegate ()
@property MouseTap *tap;
@property StatusItemController *statusController;
@property WelcomeWindowController *welcomeWindowController;
@property PrefsWindowController *prefsWindowController;
@property DebugWindowController *debugWindowController;
@property TestWindowController *testWindowController;
@property PermissionsManager *permissionsManager;
@property LoginItemController *loginItemController;
@property MouseMonitor *mouseMonitor;
@property TapLogger *logger;
@property SPUUpdater *updater;
@property SPUStandardUserDriver *updaterUserDriver;
@end

@implementation AppDelegate

// note that there is a third category of build, "Development" (see BuildScripts)
+ (NSString *)releaseChannel {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"PilotmoonReleaseChannel"];
}
+ (BOOL)appIsProductionBuild {
    return [[self releaseChannel] isEqualToString:@"Production"];
}
+ (BOOL)appIsBetaBuild {
    return [[self releaseChannel] isEqualToString:@"Beta"];
}

#pragma mark Sparkle

+ (NSString *)sparkleFeedURLString
{
    NSString *urlString=[[NSUserDefaults standardUserDefaults] stringForKey:PrefsAppcastOverrideURL];
    if (!urlString) {
        if([self appIsProductionBuild]||[self appIsBetaBuild])
        {
            // one feed for both channels; beta items are tagged with the Beta channel
            urlString=@"https://softwareupdate.pilotmoon.com/update/scrollreverser/appcast.xml";
        }
    }
    return urlString ? urlString : @"https://localhost/";
}

- (NSString *)feedURLStringForUpdater:(SPUUpdater *)updater
{
    return [[self class] sparkleFeedURLString];
}

- (NSSet<NSString *> *)allowedChannelsForUpdater:(SPUUpdater *)updater
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsBetaUpdates]) {
        return [NSSet setWithObject:@"Beta"];
    }
    return [NSSet set];
}

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SPUUpdater *)bundle
{
    return NO;
}

- (void)updater:(SPUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast
{
    NSLog(@"Loaded appcast.");
}

#pragma mark Launch and termination

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

#pragma mark Inits

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
            PrefsDiscreteScrollStepSize: @(3),
            PrefsAutoEnableWithMouse: @(NO),
            LoggerMaxEntries: @(50000),
            PrefsBetaUpdates: @([self appIsBetaBuild]),
        }];
    }
}


- (void)dealloc {
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

#pragma mark Application events

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // This setup used to be in init, but main creates the delegate before NSApplicationMain has
    // registered the app with the window server. Doing it that early made the app abort on macOS 13
    // when creating the status item, and then never receive clicks or become active.
    [[self class] terminateOthers];

    self.tap=[[MouseTap alloc] init];

    self.loginItemController=[[LoginItemController alloc] init];

    self.statusController=[[StatusItemController alloc] init];
    self.statusController.statusItemDelegate=self;
    self.statusController.visible=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PrefsHideIcon options:0 context:_contextHideIcon];
    [self.statusController attachMenu:[self makeStatusMenu]];

    self.permissionsManager=[[PermissionsManager alloc] init];

    NSBundle *const hostBundle = [NSBundle mainBundle];
    self.updaterUserDriver = [[SPUStandardUserDriver alloc] initWithHostBundle:hostBundle delegate:self];
    self.updater = [[SPUUpdater alloc] initWithHostBundle:hostBundle applicationBundle:hostBundle userDriver:self.updaterUserDriver delegate:self];
    NSError *error=nil;
    if (![self.updater startUpdater:&error]) {
        NSLog(@"Updater failed to start: %@", error);
    }
    else {
        NSLog(@"Updater started");
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Even though the app has no visible main menu, we set a minimal menu for keyboard shortcut support.
    // For example, ⌘W to close the prefs window.
    [NSApp setMainMenu:[self makeMainMenu]];

    // Show the welcome window if the user hasn't run Scroll Reverser before.
    const BOOL first=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHasRunBefore];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsHasRunBefore];
    if(first) {
        self.welcomeWindowController=[[WelcomeWindowController alloc] init];
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

    // Optionally follow whether a mouse is connected: on with a mouse, off without one.
    self.mouseMonitor=[[MouseMonitor alloc] init];
    [self.mouseMonitor addObserver:self forKeyPath:MouseMonitorKeyMouseConnected options:0 context:_contextMouseConnected];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PrefsAutoEnableWithMouse options:0 context:_contextAutoEnableWithMouse];
    [self applyAutoEnableWithMouse];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsTerminatedWithPrefsWindowOpen]) {
        [self showPrefs:self];
    }
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsTerminatedWithPrefsWindowOpen];
}

/* Recreate the event taps on wake from sleep. This works around a macOS bug, seen from 10.10 to 10.12,
 whereby the OS stopped sending gesture events to our taps after sleep, so trackpad scrolling was
 mistaken for mouse scrolling (issue #15).
 */
- (void)appDidWake:(NSNotification *)note
{
    [self logAppEvent:@"OS woke from sleep - will restart tap"];
    [self.tap restart];
}

- (void)appWillSleep:(NSNotification *)note
{
    [self logAppEvent:@"OS is going to sleep"];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self logAppEvent:@"Scroll Reverser will terminate"];
    if (self.prefsWindowController.window.visible) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsTerminatedWithPrefsWindowOpen];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    [self showPrefs:nil];
    return NO;
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key // For Applescript handling
{
    return [key isEqualToString:@"enabled"];
}

#pragma mark Menus

- (NSMenu *)makeStatusMenu
{
    NSMenu *const menu=[[NSMenu alloc] init];
    NSMenuItem *const enableItem=[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Enable %1$@", @"1=name of app e.g. `Enable Scroll Reverser`"), self.appName] action:nil keyEquivalent:@""];
    [enableItem bind:NSValueBinding toObject:self withKeyPath:@"enabled" options:nil];
    [menu addItem:enableItem];
    [menu addItem:[NSMenuItem separatorItem]];
    [self addSettingsAndQuitItemsToMenu:menu separated:NO];
    return menu;
}

- (NSMenu *)makeMainMenu
{
    NSMenu *const mainMenu=[[NSMenu alloc] init];
    NSMenu *(^addSubmenu)(NSString *)=^(NSString *title) {
        NSMenu *const submenu=[[NSMenu alloc] initWithTitle:title];
        NSMenuItem *const item=[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
        item.submenu=submenu;
        [mainMenu addItem:item];
        return submenu;
    };

    // The app menu must be the first item. Its Settings… and Quit items give ⌘, and ⌘Q while one of our windows is focused.
    NSMenu *const appMenu=addSubmenu(self.appName);
    [self addSettingsAndQuitItemsToMenu:appMenu separated:YES];

    NSMenu *const fileMenu=addSubmenu(@"File");
    [fileMenu addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];

    NSMenu *const editMenu=addSubmenu(@"Edit");
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

    NSMenu *const windowMenu=addSubmenu(@"Window");
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(miniaturize:) keyEquivalent:@"m"];

    return mainMenu;
}

// Used by both the status menu and the app menu.
- (void)addSettingsAndQuitItemsToMenu:(NSMenu *)menu separated:(BOOL)separated
{
    NSMenuItem *const settingsItem=[menu addItemWithTitle:NSLocalizedString(@"Settings…", @"Menu item that opens the settings window, including the trailing ellipsis") action:@selector(showPrefs:) keyEquivalent:@","];
    settingsItem.target=self;
    if (separated) {
        [menu addItem:[NSMenuItem separatorItem]];
    }
    NSMenuItem *const quitItem=[menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Quit %1$@", @"1=name of app e.g. `Quit Scroll Reverser`"), self.appName] action:@selector(terminate:) keyEquivalent:@"q"];
    quitItem.target=NSApp;
}

#pragma mark Logging

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

- (Logger *)startLogging
{
    if (!self.logger) {
        self.logger=[[TapLogger alloc] init];
        self.tap->logger=self.logger;
    }
    return self.logger;
}

- (void)stopLogging
{
    self.logger=nil; // the tap's reference is weak
}

- (void)logAppEvent:(NSString *)str
{
    NSString *message=[NSString stringWithFormat:@"%@ %@", str, [self settingsSummary]];
    NSLog(@"App event: %@", message);
    [self.logger logMessage:message special:YES];
}

#pragma mark Showing windows

- (IBAction)showDebug:(id)sender
{
    [NSApp activateIgnoringOtherApps:YES];
    // start logging first, so the console's own startup messages are captured
    Logger *const logger=[self startLogging];
    if(!self.debugWindowController) {
        self.debugWindowController=[[DebugWindowController alloc] init];
    }
    self.debugWindowController.logger=logger;
    [self.debugWindowController showWindow:self];
}

- (void)showPrefsWithDefaultPane:(BOOL)showDefault
{
    [NSApp activateIgnoringOtherApps:YES];
    if(!self.prefsWindowController) {
        self.prefsWindowController=[[PrefsWindowController alloc] init];
    }
    if (showDefault) {
        [self.prefsWindowController showPermissionsPane];
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
        self.testWindowController=[[TestWindowController alloc] init];
    }
    [self.testWindowController showWindow:self];
}

#pragma mark Observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context==_contextHideIcon) {
        self.statusController.visible=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon];;
    }
    else if (context==_contextEnabled) {
        self.statusController.enabled=self.enabled;
        [[NSUserDefaults standardUserDefaults] setBool:self.enabled forKey:PrefsReverseScrolling];
    }
    else if (context==_contextMouseConnected || context==_contextAutoEnableWithMouse) {
        [self applyAutoEnableWithMouse];
    }
    else if (context==_contextPermissions) {
        if(!self.permissionsManager.hasAllRequiredPermissions) {
            self.enabled=NO;
        }
        else {
            [self applyAutoEnableWithMouse];
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

- (void)applyAutoEnableWithMouse
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:PrefsAutoEnableWithMouse]) {
        return;
    }
    const BOOL connected=self.mouseMonitor.mouseConnected;
    if (connected!=self.enabled) {
        self.enabled=connected;
    }
}

#pragma mark Status item handling

- (void)statusItemClicked {
    // do nothing
}

- (void)statusItemRightClicked {
    self.enabled=!self.enabled; // toggle
}

- (void)statusItemAltClicked {
    [self showDebug:self];
}

#pragma mark Permissions

- (void)showPermissionsUI {
    [self showPrefsWithDefaultPane:YES];
}

#pragma mark Special

- (void)enableDiscreteScrollOptions
{
    [[NSUserDefaultsController sharedUserDefaultsController] setValue:@YES forKeyPath:@"values.ShowDiscreteScrollOptions"];
}

#pragma mark App info strings

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

@end

