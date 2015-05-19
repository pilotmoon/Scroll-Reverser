//
//  Logger.h
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import <Foundation/Foundation.h>

extern NSString *const LoggerEntriesChanged;
extern NSString *const LoggerMaxLines;

@interface Logger : NSObject
@property NSUInteger limit;
@property (readonly) NSUInteger entryCount;
@property BOOL enabled;

- (void)logString:(NSString *)str color:(NSColor *)color force:(BOOL)force;
- (void)logString:(NSString *)str color:(NSColor *)color;
- (void)logString:(NSString *)str;
- (void)clear;

- (NSAttributedString *)entryAtIndex:(NSUInteger)row;

@end
