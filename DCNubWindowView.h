//
//  DCPopupWindowView.h
//  dc
//
//  Created by Work on 08/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DCNubWindow.h"

@interface DCNubWindowView : NSView {
	DCNubWindow *_ownerWindow;
}
@property (readonly) DCNubWindow *ownerWindow;

- (id)initWithFrame:(NSRect)frameRect ownerWindow:(DCNubWindow *)ownerWindow;

@end
