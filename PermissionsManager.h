//
//  PermissionsManager.h
//  Scroll Reverser
//
//  Created by Nicholas Moore on 21/11/2019.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PermissionsManagerKeyAccessibilityEnabled;
extern NSString *const PermissionsManagerKeyInputMonitoringEnabled;
extern NSString *const PermissionsManagerKeyHasAllRequiredPermissions;

@interface PermissionsManager : NSObject

- (void)refresh;
@property (readonly) BOOL hasAllRequiredPermissions;

- (void)requestAccessibilityPermission;
- (void)openAccessibilityPrefs;
@property (readonly, getter=isAccessibilityRequired) BOOL accessibilityRequired;
@property (readonly, getter=isAccessibilityEnabled) BOOL accessibilityEnabled;
@property (readonly, getter=isAccessibilityRequested) BOOL accessibilityRequested;

- (void)requestInputMonitoringPermission;
- (void)openInputMonitoringPrefs;
@property (readonly, getter=isInputMonitoringRequired) BOOL inputMonitoringRequired;
@property (readonly, getter=isInputMonitoringEnabled) BOOL inputMonitoringEnabled;
@property (readonly, getter=isInputMonitoringRequested) BOOL inputMonitoringRequested;

@end

NS_ASSUME_NONNULL_END
