// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MouseMonitorKeyMouseConnected;

// Watches for external mice (USB or Bluetooth) being connected and disconnected.
// Built-in trackpads and Magic Trackpads are not counted as mice.
@interface MouseMonitor : NSObject

@property (readonly, getter=isMouseConnected) BOOL mouseConnected;

@end

NS_ASSUME_NONNULL_END
