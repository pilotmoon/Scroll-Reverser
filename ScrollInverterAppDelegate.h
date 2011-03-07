//
//  ScrollInverterAppDelegate.h
//  Scroll Inverter
//
//  Created by Work on 07/03/2011.
//  Copyright 2011 Nicholas Moore. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MouseTap;

@interface ScrollInverterAppDelegate : NSObject {
    NSWindow *window;
	MouseTap *tap;
}

@property (assign) IBOutlet NSWindow *window;

@end
