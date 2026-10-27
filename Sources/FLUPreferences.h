#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FLUMode) {
    FLUModeDisabled = 0,
    FLUModeJustNow = 1,
    FLUModeNeverUsed = 2,
    FLUModeFixedDate = 3
};

@interface FLUPreferences : NSObject
+ (instancetype)shared;
- (void)reload;
@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) FLUMode mode;
@property (nonatomic, readonly, nullable) NSDate *fixedDate;
@property (nonatomic, readonly) BOOL debugLogging;
@property (nonatomic, readonly) NSDictionary<NSString *, NSDictionary *> *appDates;
- (BOOL)hasOverrideForBundleIdentifier:(nullable NSString *)bundleIdentifier;
- (FLUMode)modeForBundleIdentifier:(nullable NSString *)bundleIdentifier;
- (nullable NSDate *)fixedDateForBundleIdentifier:(nullable NSString *)bundleIdentifier;
- (NSString *)justNowString;
- (NSString *)neverUsedString;
@end

NS_ASSUME_NONNULL_END
