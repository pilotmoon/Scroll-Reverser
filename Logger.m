//
//  Logger.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import "Logger.h"

NSString *const LoggerKeyText=@"text";
NSString *const LoggerMaxLines=@"LoggerMaxLines";

@interface Logger ()
@property NSMutableArray *logArray;
@end

@implementation Logger

- (id)init
{
    self=[super init];
    if (self) {
        self.logArray=[NSMutableArray array];
        self.limit=[[NSUserDefaults standardUserDefaults] integerForKey:LoggerMaxLines];
        self.enabled=YES;
    }
    return self;
}

- (void)append:(NSString *)str color:(NSColor *)color {
    [self willChangeValueForKey:LoggerKeyText];
    [self.logArray addObject:[[NSAttributedString alloc] initWithString:str
                                                             attributes:color?@{NSForegroundColorAttributeName: color}:@{}]];
    while (self.limit>0&&[self.logArray count]>self.limit) {
        [self.logArray removeObjectAtIndex:0];
    }
    [self didChangeValueForKey:LoggerKeyText];
}

- (void)clear
{
    [self willChangeValueForKey:LoggerKeyText];
    [self.logArray removeAllObjects];
    [self didChangeValueForKey:LoggerKeyText];
}

- (void)logString:(NSString *)str color:(NSColor *)color force:(BOOL)force
{
    if ((force||self.enabled) && [str isKindOfClass:[NSString class]])  {
        [self append:[[str stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] stringByAppendingString:@"\n"] color:color];
    }
}

- (void)logString:(NSString *)str color:(NSColor *)color
{
    [self logString:str color:color force:NO];
}

- (void)logString:(NSString *)str
{
    [self logString:str color:nil force:NO];
}

- (NSAttributedString *)text
{
    NSMutableAttributedString *text=[[NSMutableAttributedString alloc] init];
    for (NSAttributedString *s in self.logArray) {
        [text appendAttributedString:s];
    }
    return text;
}

@end
