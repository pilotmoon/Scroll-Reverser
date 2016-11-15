// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import <Cocoa/Cocoa.h>
@class Logger, LoggerScrollView, AppDelegate;

@interface DebugWindowController : NSWindowController  <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *consoleTableView;
@property (weak) IBOutlet LoggerScrollView *consoleScrollView;
@property (weak, nonatomic) Logger *logger;
@property BOOL paused;

@property (readonly) NSString *uiStringDebugConsole;
@property (readonly) NSString *uiStringClear;
@property (readonly) NSString *uiStringPause;
@property (readonly) NSString *uiStringLogState;
@property (readonly) NSString *uiStringShowTestWindow;

@property (readonly) AppDelegate *appDelegate;

- (IBAction)clearLog:(id)sender;
- (IBAction)logState:(id)sender;
- (IBAction)showDemoWindow:(id)sender;

@end
