// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>

@class SourceRow;

NS_ASSUME_NONNULL_BEGIN

// The contents of a source's info popover: its name and details.
@interface SourceInfoViewController : NSViewController

// With editable NO, the name is shown but can't be changed.
- (instancetype)initWithRow:(SourceRow *)row editable:(BOOL)editable;

@property (readonly) SourceRow *row;

@end

NS_ASSUME_NONNULL_END
