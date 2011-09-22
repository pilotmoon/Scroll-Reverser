#import "NSImage+CopySize.h"

@implementation NSImage(CopySize)

- (NSImage *)copyWithSize:(NSSize)size colorTo:(NSColor *)color
{
	[NSGraphicsContext saveGraphicsState];

	// new image to draw into
	NSImage *new=[NSImage newBlankBitmapOfSize:size];
	NSBitmapImageRep *rep=[[new representations] objectAtIndex:0];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
	
	// draw it (high quality)
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	NSRect dst=NSZeroRect;
	dst.size=size;
	[self drawInRect:dst fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	
	// recolor
	if (color) {
		[rep colorizeByMappingGray:0.5 toColor:color blackMapping:color whiteMapping:color];		
	}
	
	[NSGraphicsContext restoreGraphicsState];
	return new;
}

- (NSImage *)copyWithSize:(NSSize)size
{
	return [self copyWithSize:size colorTo:nil];
}

+ (NSImage *)newBlankBitmapOfSize:(NSSize)size;
{
	NSBitmapImageRep *rep=[[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																  pixelsWide:size.width
																  pixelsHigh:size.height
															   bitsPerSample:8
															 samplesPerPixel:4
																	hasAlpha:YES
																	isPlanar:NO
															  colorSpaceName:NSDeviceRGBColorSpace
																 bytesPerRow:0
																bitsPerPixel:0] autorelease];
	
	// blank the image
	unsigned char *data=[rep bitmapData];
	NSUInteger count=[rep bytesPerPlane];
	memset(data, 0, count);
	
	NSImage *img=[[NSImage alloc] initWithSize:size];
	[img addRepresentation:rep]; // rep is retained
	return img;
}

@end
