//
//  DebugWindowController.h
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import <Cocoa/Cocoa.h>
@class Logger, LoggerScrollView;

@interface DebugWindowController : NSWindowController

@property (unsafe_unretained) IBOutlet NSTextView *consoleTextView;
@property (weak) IBOutlet LoggerScrollView *consoleScrollView;
@property (weak, nonatomic) Logger *logger;
@property BOOL paused;

@property (readonly) NSString *uiStringDebugConsole;
@property (readonly) NSString *uiStringClear;
@property (readonly) NSString *uiStringPause;

- (IBAction)clearLog:(id)sender;

@end
