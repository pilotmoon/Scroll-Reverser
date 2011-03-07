//
//  NSImage+CopySize.h
//  dc
//
//  Created by Work on 06/08/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage(CopySize) 

- (NSImage *)copyWithSize:(NSSize)size colorTo:(NSColor *)color;
- (NSImage *)copyWithSize:(NSSize)size;
+ (NSImage *)blankBitmapOfSize:(NSSize)size;

@end
