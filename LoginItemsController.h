// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

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
