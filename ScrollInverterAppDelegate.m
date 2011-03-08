#import "ScrollInverterAppDelegate.h"
#import "MouseTap.h"
#import "NSObject+ObservePrefs.h"
#import "NSImage+CopySize.h"
#import "FCAboutController.h"
#import "DCWelcomeWindowController.h"
#import "DCStatusItemController.h"

NSString *const PrefsInvertScrolling=@"InvertScrollingOn";
NSString *const PrefsHasRunBefore=@"HasRunBefore";

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

- (id)init
{
	self=[super init];
	if (self) {
		tap=[[MouseTap alloc] init];
		tap.inverting=YES;
		statusController=[[DCStatusItemController alloc] init];
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	BOOL on=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsInvertScrolling];
	tap.inverting=on;
}

@end
