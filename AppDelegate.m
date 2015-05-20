#import "AppDelegate.h"
#import "StatusItemController.h"
#import "LoginItemsController.h"
#import "MouseTap.h"
#import "NSObject+ObservePrefs.h"
#import "WelcomeWindowController.h"
#import "PrefsWindowController.h"
#import "DebugWindowController.h"
#import "Logger.h"
#import <Sparkle/SUUpdater.h>

NSString *const PrefsReverseScrolling=@"InvertScrollingOn";
NSString *const PrefsReverseHorizontal=@"ReverseX";
NSString *const PrefsReverseVertical=@"ReverseY";
NSString *const PrefsReverseTrackpad=@"ReverseTrackpad";
NSString *const PrefsReverseMouse=@"ReverseMouse";
NSString *const PrefsReverseTablet=@"ReverseTablet";
NSString *const PrefsHasRunBefore=@"HasRunBefore";
NSString *const PrefsHideIcon=@"HideIcon";

@interface AppDelegate ()
@property BOOL ready;
@end

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

- (void)updateTap
{
	tap->inverting=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling];
    tap->invertX=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseHorizontal];
    tap->invertY=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseVertical];
    tap->invertMultiTouch=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseTrackpad];
    tap->invertTablet=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseTablet];
    tap->invertOther=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseMouse];
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
        tap=[[MouseTap alloc] init];
		[self updateTap];
        
		statusController=[[StatusItemController alloc] init];
		loginItemsController=[[LoginItemsController alloc] init];
        [loginItemsController addObserver:self forKeyPath:@"startAtLogin" options:NSKeyValueObservingOptionInitial context:nil];
        
        [self observePrefsKey:PrefsReverseScrolling];
        [self observePrefsKey:PrefsReverseHorizontal];
        [self observePrefsKey:PrefsReverseVertical];
        [self observePrefsKey:PrefsReverseTrackpad];
        [self observePrefsKey:PrefsReverseMouse];
        [self observePrefsKey:PrefsReverseTablet];
        [self observePrefsKey:PrefsHideIcon];
        
        [[SUUpdater sharedUpdater] setDelegate:self];
        [[SUUpdater sharedUpdater] setFeedURL:[self feedURL]];
    }
	return self;
}

- (NSString *)settingsSummary
{
    NSString *(^yn)(NSString *, BOOL) = ^(NSString *label, BOOL state) {
        return [NSString stringWithFormat:@"[%@ %@]", label, state?@"YES":@"NO"];
    };
    NSString *temp=yn(@"Reversing", tap->inverting);
    if (tap->inverting) {
        temp=[temp stringByAppendingString:yn(@"Vert", tap->invertY)];
        temp=[temp stringByAppendingString:yn(@"Horiz", tap->invertX)];
        temp=[temp stringByAppendingString:yn(@"Trackpad", tap->invertMultiTouch)];
        temp=[temp stringByAppendingString:yn(@"Tablet", tap->invertTablet)];
        temp=[temp stringByAppendingString:yn(@"Mouse/Other", tap->invertOther)];
    }
    return temp;
}

- (void)logAppEvent:(NSString *)str
{
    [logger logMessage:[NSString stringWithFormat:@"%@ %@", str, [self settingsSummary]] special:YES];
}

- (void)toggleReversing
{
    const BOOL state=[[NSUserDefaults standardUserDefaults]  boolForKey:PrefsReverseScrolling];
    [[NSUserDefaults standardUserDefaults] setBool:!state forKey:PrefsReverseScrolling];
}

- (void)awakeFromNib
{
	[statusController attachMenu:statusMenu];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [NSApp setMainMenu:self.theMainMenu];
    
	const BOOL first=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHasRunBefore];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsHasRunBefore];
	if(first) {
        welcomeWindowController=[[WelcomeWindowController alloc] initWithWindowNibName:@"WelcomeWindow"];
        [welcomeWindowController showWindow:self];
	}
    self.ready=YES;
    if (tap->inverting) {
        [tap start];
    }
}

- (Logger *)startLogging
{
    if (!logger) {
        tap->logger=logger=[[Logger alloc] init];
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

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsHideIcon];
    [statusController openMenu];
	return NO;
}

- (void)handleHideIconChange
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon])
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath hasSuffix:PrefsHideIcon]) {
        // run it asynchronously, because we shouldn't change the pref back inside the observer
        [self performSelector:@selector(handleHideIconChange) withObject:nil afterDelay:0.001];
    }
    else {
        [self updateTap];
        if ([keyPath hasSuffix:PrefsReverseScrolling]) {
            if (self.ready && tap->inverting) {
                [tap start];
            }
            else {
                [tap stop];
            }
        }
        [self logAppEvent:@"Settings Changed"];
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

