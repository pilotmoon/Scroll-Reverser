#import "ScrollInverterAppDelegate.h"
#import "MouseTap.h"
#import "NSObject+ObservePrefs.h"
#import "NSImage+CopySize.h"
#import "FCAboutController.h"
#import "DCWelcomeWindowController.h"
#import "DCStatusItemController.h"

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
	if ([self class]==[ScrollInverterAppDelegate class]) {
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

- (void)updateTap
{
	tap.inverting=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling];
    tap.invertX=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseHorizontal];
    tap.invertY=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseVertical];
    tap.invertMultiTouch=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseTrackpad];
    tap.invertTablet=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseTablet];
    tap.invertOther=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseMouse];
}

- (id)init
{
	self=[super init];
	if (self) {
		tap=[[MouseTap alloc] init];
		[self updateTap];
		statusController=[[DCStatusItemController alloc] init];
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

- (NSValue *)bubblePoint
{
	NSRect rect=[statusController statusItemRect];
	NSScreen *screen=[[NSScreen screens] objectAtIndex:0];
	if (screen) {
		CGFloat maxSize=[screen frame].size.height-22;
		if (rect.origin.y>maxSize) {
			rect.origin.y=maxSize;
		}
	}
	NSPoint pt=NSMakePoint(NSMidX(rect), NSMinY(rect)-0);
	return [NSValue valueWithPoint:pt];
}

- (void)awakeFromNib
{
	NSLog(@"Awake");	
	[statusController attachMenu:statusMenu];
}

- (void)doWelcome
{
	if (!welcomeController) {
		welcomeController=[[DCWelcomeWindowController alloc] init];
	}
	[welcomeController doWelcome];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSLog(@"Start");
	
	BOOL first=![[NSUserDefaults standardUserDefaults] boolForKey:PrefsHasRunBefore];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsHasRunBefore];
	if(first) {
		[self doWelcome];		
        if (NSClassFromString(@"NSPopover")) { // it is lion
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsReverseHorizontal];
        }
	}
	[tap start];
}

- (IBAction)showAbout:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	if (!aboutController) {
		aboutController=[[FCAboutController alloc] init];
	}
	[aboutController showWindow:self];
}

- (void)handleHideIcon
{
	NSLog(@"Hide icon");
	NSAlert *alert=[NSAlert alertWithMessageText:NSLocalizedString(@"Status Icon Hidden",nil)
								   defaultButton:NSLocalizedString(@"OK",nil)
								 alternateButton:NSLocalizedString(@"Restore Now",nil)
									 otherButton:nil
					   informativeTextWithFormat:NSLocalizedString(@"MENU_HIDDEN_TEXT", @"text shown when the menu bar icon is hidden")];
	const NSInteger button=[alert runModal];
    if (button==NSAlertAlternateReturn) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsHideIcon];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	NSLog(@"reveal icon");
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsHideIcon];
	return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath hasSuffix:@"HideIcon"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon])
        {
            [self handleHideIcon];
        }
    }
    else 
    {
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

