//
//  Logger.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import "Logger.h"

NSString *const LoggerUpdatesWaiting=@"LoggerUpdatesWaiting";
NSString *const LoggerEntriesChanged=@"LoggerEntriesChanged";
NSString *const LoggerEntriesAppended=@"LoggerEntriesAppended";
NSString *const LoggerEntriesRemoved=@"LoggerEntriesRemoved";
NSString *const LoggerMaxEntries=@"LoggerMaxEntries";

NSString *const LoggerKeyTimestamp=@"timestamp";
NSString *const LoggerKeyMessage=@"message";
NSString *const LoggerKeyType=@"type";

NSString *const LoggerTypeNormal=@"normal";
NSString *const LoggerTypeSpecial=@"special";

@interface Logger ()
@property NSMutableArray *logArray;
@property NSMutableArray *blockArray;
@end

@implementation Logger

- (id)init
{
    self=[super init];
    if (self) {
        self.logArray=[NSMutableArray array];
        self.blockArray=[NSMutableArray array];
        self.limit=[[NSUserDefaults standardUserDefaults] integerForKey:LoggerMaxEntries];
        self.enabled=YES;
    }
    return self;
}

- (void)append:(NSDictionary *)entry
{
    if (self.limit>0) {
        while (self.logArray.count>=self.limit) {
            [self.logArray removeObjectAtIndex:0];
            [[NSNotificationCenter defaultCenter] postNotificationName:LoggerEntriesChanged object:self userInfo:@{LoggerEntriesRemoved: [NSIndexSet indexSetWithIndex:0]}];
        }
    }
    
    const NSUInteger indexToAdd=self.logArray.count;
    [self.logArray addObject:entry];
    [[NSNotificationCenter defaultCenter] postNotificationName:LoggerEntriesChanged object:self userInfo:@{LoggerEntriesAppended: [NSIndexSet indexSetWithIndex:indexToAdd]}];
}

- (void)appendDeferred:(NSDictionary *)entry
{
    // append action to array for later processing (so log updates can be batched up in a timer)
    __weak Logger *welf=self;
    [self.blockArray addObject:[^{
        [welf append:entry];
    } copy]];
    [[NSNotificationCenter defaultCenter] postNotificationName:LoggerUpdatesWaiting object:self];
}

- (void)process
{
    [self.blockArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        void (^block)(void)=obj;
        block();
    }];
    [self.blockArray removeAllObjects];
}

- (void)clear
{
    [self.logArray removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:LoggerEntriesChanged object:self];
}

- (void)logMessage:(NSString *)str special:(BOOL)special;
{
    if ((special||self.enabled) && [str isKindOfClass:[NSString class]])  {
        [self appendDeferred:@{LoggerKeyMessage:str, LoggerKeyTimestamp:[NSDate date], LoggerKeyType:special?LoggerTypeSpecial:LoggerTypeNormal}];
    }
}

- (void)logMessage:(NSString *)str;
{
    [self logMessage:str special:NO];
}

- (NSUInteger)entryCount
{
    return self.logArray.count;
}

- (NSDictionary *)entryAtIndex:(NSUInteger)row
{
    return (row<self.logArray.count) ? self.logArray[row] : nil;
}

@end
