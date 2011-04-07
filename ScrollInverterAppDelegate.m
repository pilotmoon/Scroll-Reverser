#import "ScrollInverterAppDelegate.h"
#import "MouseTap.h"
#import "NSObject+ObservePrefs.h"
#import "NSImage+CopySize.h"
#import "FCAboutController.h"
#import "DCWelcomeWindowController.h"
#import "DCStatusItemController.h"

NSString *const PrefsInvertScrolling=@"InvertScrollingOn";
NSString *const PrefsHasRunBefore=@"HasRunBefore";
NSString *const PrefsHideIcon=@"HideIcon";

@implementation ScrollInverterAppDelegate

+ (void)initialize
{
	if ([self class]==[ScrollInverterAppDelegate class]) {
		[[NSUserDefaults standardUserDefaults] registerDefaults:
		 [NSDictionary dictionaryWithObjectsAndKeys:
		  [NSNumber numberWithBool:YES], PrefsInvertScrolling,
		  nil]];		
	}
}

- (void)updateTap
{
    BOOL on=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsInvertScrolling];
	tap.inverting=on;
}

- (id)init
{
	self=[super init];
	if (self) {
		tap=[[MouseTap alloc] init];
		[self updateTap];
		statusController=[[DCStatusItemController alloc] init];
        [self observePrefsKey:PrefsInvertScrolling];
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

- (IBAction)hideIcon:(id)sender
{
	NSLog(@"Hide icon");
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PrefsHideIcon];
	NSAlert *alert=[NSAlert alertWithMessageText:@"Status Icon Hidden"
								   defaultButton:@"OK"
								 alternateButton:nil
									 otherButton:nil
					   informativeTextWithFormat:@"The status icon has been hidden. To get it back, click Scroll Reverser in the dock or double-click its icon in Finder."];
	[alert runModal];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	NSLog(@"reveal icon");
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PrefsHideIcon];
	return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self updateTap];
}

@end
