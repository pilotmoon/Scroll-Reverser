//
//  LoggerScrollView.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import "LoggerScrollView.h"

@implementation LoggerScrollView

- (void)scrollWheel:(NSEvent *)theEvent
{
    if (self.scrollingAllowed) {
        [super scrollWheel:theEvent];
    }
}

@end
