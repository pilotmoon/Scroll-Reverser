#import <Cocoa/Cocoa.h>
@class MouseTap;

@interface ScrollInverterAppDelegate : NSObject {
	MouseTap *tap;
	NSStatusItem *statusItem;
	IBOutlet NSMenu *statusMenu;
}

@end
