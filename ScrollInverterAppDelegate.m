#import "ScrollInverterAppDelegate.h"
#import "MouseTap.h"

@implementation ScrollInverterAppDelegate

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
}
	
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSLog(@"Start");
	[tap start];
}

@end
