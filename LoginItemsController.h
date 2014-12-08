#import <Foundation/Foundation.h>

@interface LoginItemsController : NSObject {
	LSSharedFileListRef loginItems;
}

- (void)cleanup;
- (BOOL)startAtLoginWithURL:(NSURL *)bundleUrl;
- (void)setStartAtLogin:(BOOL)enabled withURL:(NSURL *)bundleUrl;
- (BOOL)startAtLogin;
- (void)setStartAtLogin:(BOOL)enabled;

@end
