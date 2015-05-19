//
//  Logger.h
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import <Foundation/Foundation.h>

extern NSString *const LoggerEntriesChanged;
extern NSString *const LoggerEntriesNewIndexes;
extern NSString *const LoggerMaxLines;

extern NSString *const LoggerKeyTimestamp;
extern NSString *const LoggerKeyMessage;
extern NSString *const LoggerKeyType;

extern NSString *const LoggerTypeNormal;
extern NSString *const LoggerTypeSpecial;

@interface Logger : NSObject
@property NSUInteger limit;
@property (readonly) NSUInteger entryCount;
@property BOOL enabled;

- (void)logMessage:(NSString *)str special:(BOOL)special;
- (void)logMessage:(NSString *)str;
- (void)clear;

- (NSDictionary *)entryAtIndex:(NSUInteger)row;

@end
