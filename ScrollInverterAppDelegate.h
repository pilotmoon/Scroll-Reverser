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
    NSMenu *statusMenu;
    NSMenuItem *startAtLoginMenu;
    NSMenuItem *startAtLoginSeparator;
}
- (IBAction)showAbout:(id)sender;
- (IBAction)startAtLoginClicked:(id)sender;



@end
