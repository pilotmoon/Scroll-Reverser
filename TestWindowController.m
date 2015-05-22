//
//  TestWindow.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 21/05/2015.
//
//

#import "TestWindowController.h"

@implementation TestWindowController

// a pseudo-random coloured pattern
- (NSImage *)testImage
{
    const int n=256;
    const CGFloat side=16;
    
    const NSRect imageRect=NSMakeRect(0, 0, n*side, n*side);
    NSImage *const image=[[NSImage alloc] initWithSize:imageRect.size];

    // draw the image
    [image lockFocus];
    {
        NSDictionary *const p=@{@0: [NSColor whiteColor],
                                @1: [NSColor colorWithCalibratedRed:0.803922 green:0.87451 blue:0.905882 alpha:1.0],
                                @2: [NSColor colorWithCalibratedRed:0.313725 green:0.670588 blue:0.74902 alpha:1.0],
                                @3: [NSColor colorWithCalibratedRed:0.0196078 green:0.203922 blue:0.345098 alpha:1.0],
                                };
        
        NSArray *const c=@[p[@0], p[@0], p[@0], p[@1], p[@1], p[@2], p[@1], p[@3], p[@3]];
        
        NSColor *(^tileColor)(void) = ^{
            return c[random()%[c count]];
        };
        
        NSRect(^tileRect)(int, int) = ^(int row, int col) {
            return NSMakeRect(col*side, row*side, side, side);
        };
        
        srandomdev();
        for (int j=0; j<n; j+=1) {
            for (int i=0; i<n; i+=1) {
                [tileColor() set];
                NSRectFill(tileRect(i,j));
            }
        }
    }
    [image unlockFocus];
    return image;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // create an image view containing the test image
    NSImage *const testImage=[self testImage];
    const NSRect testRect=NSMakeRect(0, 0, testImage.size.width, testImage.size.height);
    NSImageView *const testView=[[NSImageView alloc] initWithFrame:testRect];
    testView.image=testImage;
    [testView setBounds:testRect];
    
    // create the scroll view so that it fills the entire window
    NSScrollView *const scrollView = [[NSScrollView alloc] initWithFrame:[[self.window contentView] frame]];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    [scrollView setDocumentView:testView];
    [self.window setContentView:scrollView];
    
    // scroll to top
    [[scrollView documentView] scrollPoint:NSMakePoint(0, testImage.size.height)];
}

- (void)showWindow:(id)sender
{
    [[self window] setLevel:NSFloatingWindowLevel+1];
    [[self window] center];
    [NSApp activateIgnoringOtherApps:YES];
    dispatch_after(0.05, dispatch_get_main_queue(), ^{
        [super showWindow:sender];
    });
}

- (NSString *)uiStringTestWindow {
    return @"Scrolling Test Window";
}


@end
