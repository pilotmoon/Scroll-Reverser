// This file is part of Scroll Reverser <https://pilotmoon.com/scrollreverser/>
// Licensed under Apache License v2.0 <http://www.apache.org/licenses/LICENSE-2.0>

#import "Logger.h"
#import "MouseTap.h"

@interface TapLogger : Logger

- (void)logObject:(NSObject *)obj forCountedKey:(NSString *)key;
- (void)logObject:(NSObject *)obj forKey:(NSString *)key;
- (void)logBool:(BOOL)val forKey:(NSString *)key;
- (void)logIfYes:(BOOL)val forKey:(NSString *)key;
- (void)logSignedInteger:(NSInteger)val forKey:(NSString *)key;

- (void)logUnsignedInteger:(NSUInteger)val forKey:(NSString *)key;
- (void)logDouble:(double)val forKey:(NSString *)key;
- (void)logNanoseconds:(uint64_t)ns forKey:(NSString *)key;
- (void)logCount:(id)obj forKey:(NSString *)key;

- (void)logEventType:(CGEventType)source forKey:(NSString *)key;
- (void)logSource:(ScrollEventSource)source forKey:(NSString *)key;
- (void)logPhase:(ScrollPhase)phase forKey:(NSString *)key;

- (void)logParams;

@end
