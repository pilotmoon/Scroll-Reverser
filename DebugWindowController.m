//
//  DebugWindowController.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import "DebugWindowController.h"
#import "Logger.h"
#import "LoggerScrollView.h"

@interface DebugWindowController ()
@property NSTimer *refreshTimer;
@end

@implementation DebugWindowController

- (void)setLogger:(Logger *)logger
{
    if (_logger) {
        [_logger removeObserver:self forKeyPath:LoggerKeyText];
        [_logger unbind:@"enabled"];
    }
    if (logger) {
        [logger addObserver:self forKeyPath:LoggerKeyText options:NSKeyValueObservingOptionInitial context:nil];
        [logger bind:@"enabled" toObject:self withKeyPath:@"paused" options:@{NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName}];
    }
   _logger=logger;
}

- (void)dealloc
{
    self.logger=nil;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    self.consoleTextView.textContainer.widthTracksTextView=NO;
    self.consoleTextView.textContainer.containerSize=NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    [self addObserver:self forKeyPath:@"paused" options:NSKeyValueObservingOptionInitial context:nil];
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



- (IBAction)clearLog:(id)sender {
    [self.logger clear];
}

- (void)updateConsole
{
    NSString *const text=self.logger.text;
    self.consoleTextView.string=text;
    [self.consoleTextView scrollRangeToVisible:NSMakeRange([text length], 0)];
}

- (void)updateConsoleNeeded
{
    if (![self.refreshTimer isValid]) {
        self.refreshTimer=[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateConsole) userInfo:nil repeats:NO];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object==self.logger && [keyPath isEqualToString:LoggerKeyText]) {
        [self updateConsoleNeeded];
    }
    else if (object==self && [keyPath isEqualToString:@"paused"]) {
        self.consoleScrollView.scrollingAllowed=self.paused;
        self.consoleScrollView.hasVerticalScroller=self.paused;
    }
}

- (NSString *)uiStringDebugConsole {
    return NSLocalizedString(@"Scroll Reverser Debug Console", nil);
}

- (NSString *)uiStringClear {
    return NSLocalizedString(@"Clear", nil);
}

- (NSString *)uiStringPause {
    return NSLocalizedString(@"Pause", nil);
}

@end

