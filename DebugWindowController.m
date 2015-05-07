//
//  DebugWindowController.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import "DebugWindowController.h"
#import "Logger.h"

@interface DebugWindowController ()
@property NSTimer *refreshTimer;
@end

@implementation DebugWindowController

- (void)setLogger:(Logger *)logger
{
    if (_logger) {
        [_logger removeObserver:self forKeyPath:LoggerKeyText];
    }
    if (logger) {
        [logger addObserver:self forKeyPath:LoggerKeyText options:NSKeyValueObservingOptionInitial context:nil];
    }
   _logger=logger;
}

- (void)dealloc
{
    self.logger=nil;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)showWindow:(id)sender
{
    [[self window] setLevel:NSFloatingWindowLevel];
    [[self window] center];
    [NSApp activateIgnoringOtherApps:YES];
    // small delay to prevent flash of window drawing
    dispatch_after(0.05, dispatch_get_main_queue(), ^{
        [super showWindow:sender];
    });
}

- (NSString *)uiStringDebugConsole {
    return @"Scroll Reverser Debug Console";
}

- (NSString *)uiStringClear {
    return @"Clear";
}

- (IBAction)clearLog:(id)sender {
    [self.logger clear];
}

- (void)updateConsole
{
    self.consoleTextView.string=self.logger.text;
}

- (void)updateConsoleNeeded
{
    if (![self.refreshTimer isValid]) {
        self.refreshTimer=[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateConsole) userInfo:nil repeats:NO];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object==self.logger && [keyPath isEqualToString:LoggerKeyText]) {
        [self updateConsoleNeeded];
    }
}

@end

