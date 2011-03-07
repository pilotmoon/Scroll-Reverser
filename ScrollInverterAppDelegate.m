#import "ScrollInverterAppDelegate.h"
#import "MouseTap.h"
#import "NSObject+ObservePrefs.h"

static NSString *const PrefsInvertScrolling=@"InvertScrollingOn";

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
	}
	return self;
}

- (void)awakeFromNib
{
	NSLog(@"Awake");
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setTitle:@"SI"];
	[statusItem setHighlightMode:YES];	
	[statusItem setMenu:statusMenu];
	[self observePrefsKey:PrefsInvertScrolling];
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSLog(@"Start");
	[tap start];
}

- (IBAction)showAbout:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	BOOL on=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsInvertScrolling];
	tap.inverting=on;
}

@end
