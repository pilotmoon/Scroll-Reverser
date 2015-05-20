//
//  TapLogger.h
//  ScrollReverser
//
//  Created by Nicholas Moore on 20/05/2015.
//
//

#import "Logger.h"

@interface TapLogger : Logger

- (void)logObject:(NSObject *)obj forCountedKey:(NSString *)key;
- (void)logObject:(NSObject *)obj forKey:(NSString *)key;
- (void)logBool:(BOOL)val forKey:(NSString *)key;
- (void)logUnsignedInteger:(NSUInteger)val forKey:(NSString *)key;
- (void)logCount:(id)obj forKey:(NSString *)key;
- (void)logParams;

@end
