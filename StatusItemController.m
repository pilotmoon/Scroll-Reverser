#import "StatusItemController.h"
#import "ScrollInverterAppDelegate.h"
#import "NSObject+ObservePrefs.h"

@implementation StatusItemController

- (void)updateItems
{
	if (_menuIsOpen) {
		[_statusItem setImage:_statusImageInverse];
	}
	else {
		if ([[NSUserDefaults standardUserDefaults] boolForKey:PrefsReverseScrolling]) {
			[_statusItem setImage:_statusImage];
		}
		else {
			[_statusItem setImage:_statusImageDisabled];
		}					
	}
}

- (void)addStatusIcon
{
	if (!_statusItem) {
		_statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:[_statusImage size].width+4] retain];
        [_statusItem setMenu:_theMenu];
        [_statusItem setHighlightMode:YES];
		[self updateItems];
	}
}

- (void)removeStatusIcon
{
	if (_statusItem) {
		[[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
		[_statusItem release];
		_statusItem=nil;
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
	
	_statusImage=[[NSImage imageNamed:@"ScrollInverterStatusBlack"] retain];
	_statusImageInverse=[[NSImage imageNamed:@"ScrollInverterStatusWhite"] retain];
	_statusImageDisabled=[[NSImage imageNamed:@"ScrollInverterStatusGrey"] retain];
	[self observePrefsKey:PrefsReverseScrolling];
	[self observePrefsKey:PrefsHideIcon];	
	[self displayStatusIcon];
	
	return self;
}

- (void)menuWillOpen:(NSMenu *)menu
{
	_menuIsOpen=YES;
	[self updateItems];
}

- (void)menuDidClose:(NSMenu *)menu
{
	_menuIsOpen=NO;
	[self updateItems];	
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self displayStatusIcon];
	[self updateItems];
}

- (void)attachMenu:(NSMenu *)menu
{
    _theMenu=menu;
	[_theMenu setDelegate:self];
    [_statusItem setMenu:_theMenu];
}

@end
