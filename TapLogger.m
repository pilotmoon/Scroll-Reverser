//
//  TapLogger.m
//  ScrollReverser
//
//  Created by Nicholas Moore on 20/05/2015.
//
//

#import "TapLogger.h"

@interface TapLogger ()
@property NSMutableDictionary *params;
@property NSMutableDictionary *keyCounts;
@property NSMutableOrderedSet *keyOrder;
@property NSUInteger serial;
@end

@implementation TapLogger

- (id)init
{
    self=[super init];
    if (self) {
        self.params=[NSMutableDictionary dictionary];
        self.keyCounts=[NSMutableDictionary dictionary];
        self.keyOrder=[NSMutableOrderedSet orderedSet];
    }
    return self;
}

- (void)logObject:(NSObject *)obj forCountedKey:(NSString *)key
{
    if (obj&&key) {
        NSNumber *count=@([self.keyCounts[key] unsignedIntegerValue]+1);
        self.keyCounts[key]=count;
        NSString *adjustedKey=[NSString stringWithFormat:@"%@%@", key, count];
        [self.keyOrder addObject:adjustedKey];
        self.params[adjustedKey]=obj;
    }
}

- (void)logObject:(NSObject *)obj forKey:(NSString *)key
{
    if (obj&&key) {
        [self.keyOrder addObject:key];
        self.params[key]=obj;
    }
}

- (void)logBool:(BOOL)val forKey:(NSString *)key
{
    [self logObject:val?@"yes":@"no" forKey:key];
}

- (void)logUnsignedInteger:(NSUInteger)val forKey:(NSString *)key
{
    [self logObject:@(val) forKey:key];
}

- (void)logCount:(id)obj forKey:(NSString *)key
{
    [self logObject:@([obj count]) forKey:key];
}

- (void)logParams
{
    NSMutableString *const paramString=[[NSString stringWithFormat:@"%@ ", @(self.serial++)] mutableCopy];
    
    void (^p)(NSString *, NSObject *) = ^(NSString *label, NSObject *obj) {
        [paramString appendFormat:@"[%@ %@]", label, obj];
    };
    
    for (NSString *key in self.keyOrder) {
        p(key, self.params[key]);
    }
    
    [self logMessage:paramString];
    [self.params removeAllObjects];
    [self.keyCounts removeAllObjects];
    [self.keyOrder removeAllObjects];
}

@end
