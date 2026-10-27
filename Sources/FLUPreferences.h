#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FLUMode) {
    FLUModeDisabled = 0,
    FLUModeJustNow = 1,     // «Только что»
    FLUModeNeverUsed = 2,   // «Не использовалось»
    FLUModeFixedDate = 3    // фиксированная дата
};

@interface FLUPreferences : NSObject

+ (instancetype)shared;
- (void)reload;

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) FLUMode mode;
@property (nonatomic, readonly, nullable) NSDate *fixedDate;
@property (nonatomic, readonly) BOOL debugLogging;

/// Localized-ish display strings (UI may still format dates itself).
- (NSString *)justNowString;
- (NSString *)neverUsedString;

@end

NS_ASSUME_NONNULL_END
