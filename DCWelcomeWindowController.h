//
//  DCWelcomeWindowController.h
//  dc
//
//  Created by Work on 18/06/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class DCBubbleWindow;

@interface DCWelcomeWindowController : NSObject {
	IBOutlet NSButton *startupSetting;
	IBOutlet NSView *welcomeView;
	DCBubbleWindow *window;
	NSNib *nib;
}
- (IBAction)handleButton:(id)sender;
- (void)doWelcome;

@end
