#import <Cocoa/Cocoa.h>

@interface NSImage(CopySize) 

- (NSImage *)copyWithSize:(NSSize)size colorTo:(NSColor *)color;
- (NSImage *)copyWithSize:(NSSize)size;
+ (NSImage *)newBlankBitmapOfSize:(NSSize)size;

@end
