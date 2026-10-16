// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>
#import "SourceTable.h"

NS_ASSUME_NONNULL_BEGIN

// The localized names and descriptions of a source, for the settings window.
@interface SourceRow (Display)

// The custom name if there is one, or else the default name. Observable.
@property (readonly) NSString *displayName;
// A name made from what the source reported, or a description of it if it reported nothing.
@property (readonly) NSString *defaultName;
@property (readonly) NSImage *icon;

@property (readonly) NSString *kindDescription;
@property (readonly) NSString *scrollingTypeDescription;
@property (readonly) NSString *systemDirectionDescription;

@end

// The name of a scrolling mode, as in the Scrolling menu.
NSString *SourceDirectionModeTitle(ScrollDirectionMode mode);

NS_ASSUME_NONNULL_END
