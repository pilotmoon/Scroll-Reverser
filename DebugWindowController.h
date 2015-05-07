//
//  DebugWindowController.h
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import <Cocoa/Cocoa.h>
@class Logger;

@interface DebugWindowController : NSWindowController

@property (unsafe_unretained) IBOutlet NSTextView *consoleTextView;
@property (weak, nonatomic) Logger *logger;

@property (readonly) NSString *uiStringDebugConsole;
@property (readonly) NSString *uiStringClear;

- (IBAction)clearLog:(id)sender;

@end
