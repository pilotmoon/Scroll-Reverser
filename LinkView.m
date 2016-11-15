// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "LinkView.h"

@implementation LinkView

- (void)resetCursorRects
{
    [self addCursorRect:[self bounds] cursor:[NSCursor pointingHandCursor]];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (self.url) {
        [[NSWorkspace sharedWorkspace] openURL:self.url];
    }
}

@end
