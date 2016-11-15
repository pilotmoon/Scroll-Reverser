// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// (c) Nicholas Moore. Licensed under Apache License v2.0 (see LICENSE).

#import <Foundation/Foundation.h>

extern NSString *const LoggerUpdatesWaiting;
extern NSString *const LoggerEntriesChanged;
extern NSString *const LoggerEntriesAppended;
extern NSString *const LoggerEntriesRemoved;
extern NSString *const LoggerMaxEntries;

extern NSString *const LoggerKeyTimestamp;
extern NSString *const LoggerKeyMessage;
extern NSString *const LoggerKeyType;

extern NSString *const LoggerTypeNormal;
extern NSString *const LoggerTypeSpecial;

@interface Logger : NSObject
@property (readonly) NSUInteger entryCount;
@property BOOL enabled;
@property NSUInteger limit;

- (void)logMessage:(NSString *)str special:(BOOL)special;
- (void)logMessage:(NSString *)str;
- (void)clear;

- (NSDictionary *)entryAtIndex:(NSUInteger)row;

- (void)process;

@end
