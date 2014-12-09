//
//  LinkView.m
//  ScrollInverter
//
//  Created by Nicholas Moore on 09/12/2014.
//
//

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
