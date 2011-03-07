#import <Foundation/Foundation.h>

@interface LoginItemsController : NSObject {
	__strong LSSharedFileListRef loginItems;
}

// "Start at Login" property to be bound to by prefs checkbox.
@property BOOL startAtLogin;

+ (LoginItemsController *)sharedInstance;
- (void)cleanup;
- (BOOL)startAtLoginWithURL:(NSURL *)bundleUrl;
- (void)setStartAtLogin:(BOOL)enabled withURL:(NSURL *)bundleUrl;
- (BOOL)startAtLogin;
- (void)setStartAtLogin:(BOOL)enabled;

@end
