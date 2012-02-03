#import <Cocoa/Cocoa.h>
@class MouseTap, StatusItemController, LoginItemsController;

extern NSString *const PrefsReverseScrolling;
extern NSString *const PrefsReverseHorizontal;
extern NSString *const PrefsReverseVertical;
extern NSString *const PrefsReverseTrackpad;
extern NSString *const PrefsReverseMouse;
extern NSString *const PrefsReverseTablet;
extern NSString *const PrefsHideIcon;

@interface ScrollInverterAppDelegate : NSObject {
	MouseTap *tap;
	StatusItemController *statusController;
    LoginItemsController *loginItemsController;
    IBOutlet NSMenu *statusMenu;
    IBOutlet NSMenuItem *startAtLoginMenu;
}
- (IBAction)showAbout:(id)sender;
- (IBAction)startAtLoginClicked:(id)sender;
- (IBAction)menuItemClicked:(id)sender;


@end
