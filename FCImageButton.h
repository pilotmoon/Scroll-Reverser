//
//  FCImageButton.h
//  fc
//
//  Created by Work on 15/02/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FCImageButton : NSButton {
	BOOL mouseIn;
}
@property (readonly) BOOL mouseIn;
@end
