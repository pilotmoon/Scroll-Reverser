#import <Cocoa/Cocoa.h>
@class MouseTap, StatusItemController;

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
    NSMenu *_statusMenu;
}
@property (assign) IBOutlet NSMenu *statusMenu;
- (IBAction)showAbout:(id)sender;

@end
