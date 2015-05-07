//
//  Logger.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import "Logger.h"

NSString *const LoggerKeyText=@"text";

@interface Logger ()
@property NSMutableArray *logArray;
@end

@implementation Logger

- (id)init
{
    self=[super init];
    if (self) {
        self.logArray=[NSMutableArray array];
        self.limit=50000; // default
        self.enabled=YES;
    }
    return self;
}

- (void)append:(NSString *)str color:(NSColor *)color {
    [self willChangeValueForKey:LoggerKeyText];
    NSDictionary *attrs=color?@{NSForegroundColorAttributeName: color}:@{};
    NSAttributedString *as=[[NSAttributedString alloc] initWithString:str attributes:attrs];
    [self.logArray addObject:as];
    while ([self.logArray count]>self.limit) {
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
        [self append:[str stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] color:color];
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
    [text.mutableString appendString:@"\n"];
    
    }
    return text;
}

@end
