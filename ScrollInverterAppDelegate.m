#import "ScrollInverterAppDelegate.h"
#import "MouseTap.h"
#import "NSObject+ObservePrefs.h"
#import "NSImage+CopySize.h"
#import "FCAboutController.h"

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

- (void)setStatusImage
{
	BOOL on=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsInvertScrolling];
	if (on) {
		[statusItem setImage:statusImage];
	}
	else {
		[statusItem setImage:statusImageDisabled];
	}
}

- (void)awakeFromNib
{
	NSLog(@"Awake");

	// load images
	NSImage *original=[NSImage imageNamed:@"ScrollInverterStatus"];
	NSSize statusSize=NSMakeSize(14,18);
	statusImage=[original copyWithSize:statusSize colorTo:[NSColor blackColor]];
	statusImageInverse=[original copyWithSize:statusSize colorTo:[NSColor whiteColor]];
	statusImageDisabled=[original copyWithSize:statusSize colorTo:[NSColor grayColor]];
	
	// initialize status item
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[self setStatusImage];
	[statusItem setAlternateImage:statusImageInverse];
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
	if (!aboutController) {
		aboutController=[[FCAboutController alloc] init];
	}
	[aboutController showWindow:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	BOOL on=[[NSUserDefaults standardUserDefaults] boolForKey:PrefsInvertScrolling];
	[self setStatusImage];
	tap.inverting=on;
}

@end
