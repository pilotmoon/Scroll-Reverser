// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>

@class SourceRow;

NS_ASSUME_NONNULL_BEGIN

// The contents of a source's info popover: its name, horizontal scrolling and details.
@interface SourceInfoViewController : NSViewController

- (instancetype)initWithRow:(SourceRow *)row;

@property (readonly) SourceRow *row;

@end

NS_ASSUME_NONNULL_END
