//
//  DebugWindowController.h
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import <Cocoa/Cocoa.h>
@class Logger, LoggerScrollView;

@interface DebugWindowController : NSWindowController  <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *consoleTableView;
@property (weak) IBOutlet LoggerScrollView *consoleScrollView;
@property (weak, nonatomic) Logger *logger;
@property BOOL paused;

@property (readonly) NSString *uiStringDebugConsole;
@property (readonly) NSString *uiStringClear;
@property (readonly) NSString *uiStringPause;
@property (readonly) NSString *uiStringLogState;

- (IBAction)clearLog:(id)sender;
- (IBAction)logState:(id)sender;

@end
