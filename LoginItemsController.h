#ifndef TIGER_BUILD
#import <Foundation/Foundation.h>

@interface LoginItemsController : NSObject {
	LSSharedFileListRef loginItems;
}

+ (LoginItemsController *)sharedInstance;
- (void)cleanup;
- (BOOL)startAtLoginWithURL:(NSURL *)bundleUrl;
- (void)setStartAtLogin:(BOOL)enabled withURL:(NSURL *)bundleUrl;
- (BOOL)startAtLogin;
- (void)setStartAtLogin:(BOOL)enabled;

@end
#endif
