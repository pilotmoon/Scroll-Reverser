// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// (c) Nicholas Moore. Licensed under Apache License v2.0 (see LICENSE).

#import "LoggerScrollView.h"

@implementation LoggerScrollView

- (void)scrollWheel:(NSEvent *)theEvent
{
    if (self.scrollingAllowed) {
        [super scrollWheel:theEvent];
    }
}

@end
