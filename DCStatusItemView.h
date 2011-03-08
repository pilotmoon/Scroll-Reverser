//
//  DCStatusItemView.h
//  dc
//
//  Created by Work on 20/12/2010.
//  Copyright 2010 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DCStatusItemController;

@interface DCStatusItemView : NSButton {
	__weak DCStatusItemController *controller;
}

- (id)initWithFrame:(NSRect)frame controller:(DCStatusItemController *)aController;

@end
