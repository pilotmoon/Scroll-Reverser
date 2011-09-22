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
	MouseTap *_tap;
	StatusItemController *_statusController;
    LoginItemsController *_loginItemsController;
    NSMenu *_statusMenu;
    NSMenuItem *_startAtLoginMenu;
    NSMenuItem *_startAtLoginSeparator;
}
@property (assign) IBOutlet NSMenu *statusMenu;
@property (assign) IBOutlet NSMenuItem *startAtLoginMenu;
@property (assign) IBOutlet NSMenuItem *startAtLoginSeparator;- (IBAction)showAbout:(id)sender;
- (IBAction)startAtLoginClicked:(id)sender;



@end
