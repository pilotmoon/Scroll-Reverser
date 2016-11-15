// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "LoggerScrollView.h"

@implementation LoggerScrollView

- (void)scrollWheel:(NSEvent *)theEvent
{
    if (self.scrollingAllowed) {
        [super scrollWheel:theEvent];
    }
}

@end
