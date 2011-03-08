//
//  FCButtonCell.h
//  fc
//
//  Created by Work on 04/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FCButtonCell : NSButtonCell {
	NSColor *backgroundColor;
	NSColor *borderColor;
}
@property (retain) NSColor *backgroundColor;
@property (retain) NSColor *borderColor;

@end
