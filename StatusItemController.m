#import "StatusItemController.h"
#import "ScrollInverterAppDelegate.h"
#import "NSImage+CopySize.h"
#import "NSObject+ObservePrefs.h"

static NSSize _iconSize;
#define ICON_PADDING 4

@implementation StatusItemController
@synthesize statusItem, menuIsOpen;

- (void)updateItems
{
	if (menuIsOpen) {
		[statusItem setImage:statusImageInverse];
	}
	else {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling]) {
			[statusItem setImage:statusImage];
		}
		else {
			[statusItem setImage:statusImageDisabled];
		}					
	}
}

- (void)addStatusIcon
{
	if (!statusItem) {
		const float width = _iconSize.width+ICON_PADDING;
		statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:width] retain];
		[self updateItems];
		[[statusItem view] display];			
	}
}

- (void)removeStatusIcon
{
	if (statusItem) {
		[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
		[statusItem release];
		statusItem=nil;
	}
}

- (void)displayStatusIcon
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsHideIcon]) {
		[self removeStatusIcon];
	}
	else {
		[self addStatusIcon];
	}
}

- (id)init
{
	self = [super init];
	
	_iconSize=NSMakeSize(14, 17);
	
	// Loadup status icons.
	NSImage *original=[NSImage imageNamed:@"ScrollInverterStatus"];
	
	statusImage=[original copyWithSize:_iconSize];
	statusImageInverse=[original copyWithSize:_iconSize colorTo:[NSColor whiteColor]];
    
	/* Gray icon needs coloring before sizing due to aliasing effects. */
	NSImage *grayTemp=[[original copyWithSize:[original size] colorTo:[NSColor colorWithDeviceRed:0.6 green:0.6 blue:0.6 alpha: 1.0]] autorelease]; 
	statusImageDisabled=[grayTemp copyWithSize:_iconSize];	
	
	[self displayStatusIcon];
	
    /* Observe prefs keys that can affect the icon */
	[self observePrefsKey:PrefsReverseScrolling];
	[self observePrefsKey:PrefsHideIcon];
	
	canOpenMenu=YES;
	
	return self;
}

- (void)menuWillOpen:(NSMenu *)menu
{
	menuIsOpen=YES;
	canOpenMenu=NO;
	[self updateItems];
}

- (void)allowOpen
{
	canOpenMenu=YES;
}

- (void)menuDidClose:(NSMenu *)menu
{
	menuIsOpen=NO;
	[self updateItems];	
	[self performSelector:@selector(allowOpen) withObject:nil afterDelay:0.3];
}

- (void)attachMenu:(NSMenu *)menu
{
	theMenu=menu;
	[menu setDelegate:self];
}

- (void)showAttachedMenu:(BOOL)force
{
	if (force || (!menuIsOpen && canOpenMenu))
    {
		[statusItem popUpStatusItemMenu:theMenu];
	}
}

- (void)showAttachedMenu
{
	[self showAttachedMenu:NO];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self displayStatusIcon];
	[self updateItems];
}

@end
