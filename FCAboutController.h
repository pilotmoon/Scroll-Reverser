//
//  FCAboutController.h
//  fc
//
//  Created by Work on 25/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FCButton.h"
@interface FCAboutController : NSWindowController {
	IBOutlet NSView *contents;
	NSNib *nib;
	IBOutlet FCButton *linkButton1;
	IBOutlet FCButton *linkButton2;
}
- (IBAction)closeAboutWindow:(id)sender;
- (IBAction)linkButton1:(id)sender;
- (IBAction)linkButton2:(id)sender;
@end
