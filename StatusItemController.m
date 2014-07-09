#import "StatusItemController.h"
#import "ScrollInverterAppDelegate.h"
#import "NSObject+ObservePrefs.h"

@implementation StatusItemController

- (void)addStatusIcon
{
	if (!_statusItem) {
        _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        [_statusItem setMenu:_theMenu];
        [_statusItem setHighlightMode:YES];

    	_statusImage = [NSImage imageNamed:@"ScrollInverterStatusBlack"];
        [_statusImage setTemplate:YES];
        NSSize iconSize=NSMakeSize(14, 17);
        [_statusImage setSize:iconSize];
        [_statusItem setImage:_statusImage];
	}
}

- (void)removeStatusIcon
{
	if (_statusItem) {
		[[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
		_statusItem=nil;
        _statusImage=nil;
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

	[self observePrefsKey:PrefsHideIcon];
	[self displayStatusIcon];
	
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self displayStatusIcon];
}

- (void)attachMenu:(NSMenu *)menu
{
    _theMenu=menu;
    [_statusItem setMenu:_theMenu];
}

@end
