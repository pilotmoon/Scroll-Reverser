#import "ScrollInverterAppDelegate.h"
#import "StatusItemController.h"
#import "LoginItemsController.h"
#import "MouseTap.h"
#import "NSObject+ObservePrefs.h"

NSString *const PrefsReverseScrolling=@"InvertScrollingOn";
NSString *const PrefsReverseHorizontal=@"ReverseX";
NSString *const PrefsReverseVertical=@"ReverseY";
NSString *const PrefsReverseTrackpad=@"ReverseTrackpad";
NSString *const PrefsReverseMouse=@"ReverseMouse";
NSString *const PrefsReverseTablet=@"ReverseTablet";
NSString *const PrefsHasRunBefore=@"HasRunBefore";
NSString *const PrefsHideIcon=@"HideIcon";

@implementation ScrollInverterAppDelegate

+ (void)initialize
{
	if ([self class]==[ScrollInverterAppDelegate class])
    {
		[[NSUserDefaults standardUserDefaults] registerDefaults:
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithBool:YES], PrefsReverseScrolling,
		  [NSNumber numberWithBool:YES], PrefsReverseHorizontal,
          [NSNumber numberWithBool:YES], PrefsReverseVertical,
          [NSNumber numberWithBool:YES], PrefsReverseTrackpad,
          [NSNumber numberWithBool:YES], PrefsReverseMouse,
          [NSNumber numberWithBool:YES], PrefsReverseTablet,
          nil]];		
	}
}

static BOOL terminateApp(NSDictionary *appDict)
{
    pid_t pid=[[appDict objectForKey:@"NSApplicationProcessIdentifier"] intValue];
	ProcessSerialNumber psn={0, 0};
	OSStatus status=GetProcessForPID(pid, &psn);
	if (status==noErr)
	{
        AppleEvent tAppleEvent;
        AEBuildError tAEBuildError;
        status = AEBuildAppleEvent( kCoreEventClass, kAEQuitApplication, typeProcessSerialNumber, &psn,
                                   sizeof(ProcessSerialNumber), kAutoGenerateReturnID, kAnyTransactionID, &tAppleEvent, &tAEBuildError,"");
        if (status==noErr)
        {
            status = AESendMessage(&tAppleEvent, NULL, kAEAlwaysInteract+kAENoReply, kNoTimeOut);
        }
	}
    return status==noErr;
}

+ (BOOL)isAlreadyRunning;
{
	NSDictionary *appDict=nil;
	for (appDict in [[NSWorkspace sharedWorkspace] launchedApplications]) {
		if (![[appDict objectForKey:@"NSApplicationProcessIdentifier"] intValue]==getpid()) {
			if ([[[appDict objectForKey:@"NSApplicationBundleIdentifier"] lowercaseString] isEqualToString:[@"com.pilotmoon.scroll-reverser" lowercaseString]]) {
				break;
			}			
		}
	}
	
	if (appDict) { 
        
        if (terminateApp(appDict))
        {
            // just silently quit the other, and update the start at login
            NSURL *url=[NSURL fileURLWithPath:[appDict objectForKey:@"NSApplicationPath"]];
            if ([[LoginItemsController sharedInstance] startAtLoginWithURL:url]) {
                [[LoginItemsController sharedInstance] setStartAtLogin:NO withURL:url];
                [[LoginItemsController sharedInstance] setStartAtLogin:YES withURL:[[NSBundle mainBundle] bundleURL]];
            }
        }
        else {
            NSString *thisAppName=@"Scroll Reverser";
            NSString *otherAppName=[appDict objectForKey:@"NSApplicationName"];
            NSString *otherCopyText=[thisAppName isEqualToString:otherAppName]?@"another copy":otherAppName;
            NSAlert *alert=[NSAlert alertWithMessageText:[NSString stringWithFormat:@"%@ is already running.", otherAppName]
                                           defaultButton:@"Quit"
                                         alternateButton:nil
                                             otherButton:nil
                               informativeTextWithFormat:@"%@ cannot start while %@ is running.", thisAppName, otherCopyText];
            [alert runModal];
            return YES;
        }
	}
	return NO;
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

- (id)init
{
	self=[super init];
	if (self) {
		tap=[[MouseTap alloc] init];
		[self updateTap];
		statusController=[[StatusItemController alloc] init];
        
        // if leopard or above
#ifndef TIGER_BUILD
		loginItemsController=[[LoginItemsController alloc] init];
#endif
        
        [self observePrefsKey:PrefsReverseScrolling];
        [self observePrefsKey:PrefsReverseHorizontal];
        [self observePrefsKey:PrefsReverseVertical];
        [self observePrefsKey:PrefsReverseTrackpad];
        [self observePrefsKey:PrefsReverseMouse];
        [self observePrefsKey:PrefsReverseTablet];
        [self observePrefsKey:PrefsHideIcon];
    }
	return self;
}

-(IBAction) menuItemClicked:(id)sender
{
	NSLog(@"MIC");
	switch ([sender tag])
	{

#ifndef TIGER_BUILD	
		case 31:

			if (loginItemsController) {
				const BOOL newState=![loginItemsController startAtLogin];
				[loginItemsController setStartAtLogin:newState];
				[startAtLoginMenu setState:newState];
			}
		break;
#endif			
			
		default:
			break;
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	return YES;
}

- (void)awakeFromNib
{
	[self willChangeValueForKey:@"startAtLoginEnabled"];
	[statusMenu setAutoenablesItems:YES];
	[statusController attachMenu:statusMenu];
#ifndef TIGER_BUILD
	[loginItemsController addObserver:self forKeyPath:@"startAtLogin" options:NSKeyValueObservingOptionInitial context:nil];
#else
	[prefsMenu removeItem:startAtLoginMenu];
	[prefsMenu removeItem:startAtLoginSeparator];
	[prefsMenu removeItem:trackpadItemMenu];
#endif
	[self didChangeValueForKey:@"startAtLoginEnabled"];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	const BOOL first=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHasRunBefore];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsHasRunBefore];
	if(first) {
        if (NSClassFromString(@"NSPopover")) { // it is lion
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsReverseHorizontal];
        }
	}
	[tap start];
}

- (IBAction)showAbout:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
    NSDictionary *dict=[NSDictionary dictionaryWithObjectsAndKeys:
                        @"Scroll Reverser", @"ApplicationName",
                        nil];
    [NSApp orderFrontStandardAboutPanelWithOptions:dict];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsHideIcon];
	return NO;
}

- (void)handleHideIconChange
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon])
    {
		[NSApp activateIgnoringOtherApps:YES];
        NSAlert *alert=[NSAlert alertWithMessageText:NSLocalizedString(@"Status Icon Hidden",nil)
                                       defaultButton:NSLocalizedString(@"OK",nil)
                                     alternateButton:NSLocalizedString(@"Restore Now",nil)
                                         otherButton:nil
                           informativeTextWithFormat:NSLocalizedString(@"MENU_HIDDEN_TEXT", @"text shown when the menu bar icon is hidden")];
        const unsigned long button=[alert runModal];
        if (button==NSAlertAlternateReturn) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsHideIcon];
        }
    }    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object==loginItemsController) {
#ifndef TIGER_BUILD
        [startAtLoginMenu setState:[loginItemsController startAtLogin]];
#endif
    }
    else if ([keyPath hasSuffix:@"HideIcon"]) {
        // run it asynchronously, because we shouldn't change the pref back inside the observer
        [self performSelector:@selector(handleHideIconChange) withObject:nil afterDelay:0.001];
    }
    else {
        [self updateTap];
    }
}

- (NSString *)menuStringReverseScrolling {
	return NSLocalizedString(@"Reverse Scrolling", nil);
}
- (NSString *)menuStringAbout {
	return NSLocalizedString(@"About", nil);
}
- (NSString *)menuStringPreferences {
	return NSLocalizedString(@"Preferences", nil);
}
- (NSString *)menuStringQuit {
	return NSLocalizedString(@"Quit Scroll Reverser", nil);
}
- (NSString *)menuStringStartAtLogin {
	return NSLocalizedString(@"Start at Login", nil);
}
- (NSString *)menuStringShowInMenuBar {
	return NSLocalizedString(@"Show in Menu Bar", nil);
}
- (NSString *)menuStringHorizontal {
	return NSLocalizedString(@"Reverse Horizontal", nil);
}
- (NSString *)menuStringVertical {
	return NSLocalizedString(@"Reverse Vertical", nil);
}
- (NSString *)menuStringTrackpad {
	return NSLocalizedString(@"Reverse Trackpad", nil);
}
- (NSString *)menuStringMouse {
	return NSLocalizedString(@"Reverse Mouse", nil);
}
- (NSString *)menuStringTablet {
	return NSLocalizedString(@"Reverse Tablet", nil);
}

@end

