// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>

@class SourceTable;

NS_ASSUME_NONNULL_BEGIN

/* The table of scroll sources in the settings window, with a remove button below it. Rows are in
 most-recently-used order, kept up to date while the window is open, and a row is highlighted
 while its source is scrolling. */
@interface SourcesTableController : NSObject <NSTableViewDataSource, NSTableViewDelegate>

- (instancetype)initWithSourceTable:(SourceTable *)sourceTable;

@property (readonly) NSView *view;

// Keep the table up to date only while the window is open.
- (void)windowWillShow;
- (void)windowWillClose;

@end

NS_ASSUME_NONNULL_END
