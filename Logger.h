//
//  Logger.h
//  ScrollReverser
//
//  Created by Nicholas Moore on 07/05/2015.
//
//

#import <Foundation/Foundation.h>

extern NSString *const LoggerKeyText;

@interface Logger : NSObject
@property NSUInteger limit;
@property (readonly) NSAttributedString *text;
@property BOOL enabled;

- (void)logString:(NSString *)str color:(NSColor *)color force:(BOOL)force;
- (void)logString:(NSString *)str color:(NSColor *)color;
- (void)logString:(NSString *)str;
- (void)clear;
@end
