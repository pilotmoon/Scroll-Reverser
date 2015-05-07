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
    }
    return self;
}

- (void)append:(NSString *)str {
    [self willChangeValueForKey:LoggerKeyText];
    [self.logArray addObject:str];
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

- (void)logString:(NSString *)str
{
    if ([str isKindOfClass:[NSString class]]) {
        [self append:[str stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
    }
}

- (NSString *)text
{
    return [self.logArray componentsJoinedByString:@"\n"];
}

@end
