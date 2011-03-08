//
//  DCPopupWindowView.m
//  dc
//
//  Created by Work on 08/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import "DCNubWindowView.h"


@implementation DCNubWindowView

- (id)initWithFrame:(NSRect)frameRect ownerWindow:(DCNubWindow *)ownerWindow
{
	self=[super initWithFrame:frameRect];
	if (self) {
		_ownerWindow=ownerWindow;
	}
	return self;
}
- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
	if ([newWindow isKindOfClass:[DCNubWindow class]]) {
		_ownerWindow=(DCNubWindow *)newWindow;			
	}
}
- (DCNubWindow *)ownerWindow
{
	return _ownerWindow;
}
@end
