// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// (c) Nicholas Moore. Licensed under Apache License v2.0 (see LICENSE).

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
