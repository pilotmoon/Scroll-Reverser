//
//  Logger.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import "Logger.h"

NSString *const LoggerEntriesChanged=@"LoggerEntriesChanged";
NSString *const LoggerMaxLines=@"LoggerMaxLines";

NSString *const LoggerKeyTimestamp=@"timestamp";
NSString *const LoggerKeyMessage=@"message";
NSString *const LoggerKeyType=@"type";

NSString *const LoggerTypeNormal=@"normal";
NSString *const LoggerTypeSpecial=@"special";

@interface Logger ()
@property NSMutableArray *logArray;
@property NSUInteger removedRowCount;
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

- (void)append:(NSDictionary *)entry
{
    const NSUInteger addedRowIndex=self.logArray.count;
    if (addedRowIndex>self.limit) {
        return;
    }
    if (addedRowIndex==self.limit) {
        entry=@{LoggerKeyMessage: @"Log full. Clear to resume logging."};
    }
    
    [self.logArray addObject:entry];
    [[NSNotificationCenter defaultCenter] postNotificationName:LoggerEntriesChanged object:self];
}

- (void)clear
{
    [self.logArray removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:LoggerEntriesChanged object:self];
}

- (void)logMessage:(NSString *)str special:(BOOL)special;
{
    if ((special||self.enabled) && [str isKindOfClass:[NSString class]])  {
        [self append:@{LoggerKeyMessage:str, LoggerKeyTimestamp:[NSDate date], LoggerKeyType:special?LoggerTypeSpecial:LoggerTypeNormal}];
    }
}

- (void)logMessage:(NSString *)str;
{
    [self logMessage:str special:NO];
}

- (NSUInteger)entryCount
{
    return self.logArray.count+self.removedRowCount;
}

- (NSDictionary *)entryAtIndex:(NSUInteger)row
{
    if (row>=self.removedRowCount) {
        const NSUInteger adjustedRow=row-self.removedRowCount;
        if (adjustedRow<self.logArray.count) {
            return self.logArray[adjustedRow];
        }
    }

    return nil;
}

@end
