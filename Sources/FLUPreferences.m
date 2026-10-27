#import "FLUPreferences.h"

static NSString * const kPath = @"/var/jb/var/mobile/Library/Preferences/com.storagefake.lastused.plist";

@implementation FLUPreferences {
    BOOL _enabled;
    FLUMode _mode;
    NSDate *_fixedDate;
    BOOL _debugLogging;
}

+ (instancetype)shared {
    static FLUPreferences *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) [self reload];
    return self;
}

- (void)reload {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kPath];
    _enabled = d[@"Enabled"] ? [d[@"Enabled"] boolValue] : YES;
    _debugLogging = d[@"DebugLogging"] ? [d[@"DebugLogging"] boolValue] : NO;

    NSString *mode = [d[@"Mode"] description] ?: @"justnow";
    mode = mode.lowercaseString;
    if ([mode isEqualToString:@"never"] || [mode isEqualToString:@"neverused"]) {
        _mode = FLUModeNeverUsed;
    } else if ([mode isEqualToString:@"fixed"] || [mode isEqualToString:@"custom"]) {
        _mode = FLUModeFixedDate;
    } else if ([mode isEqualToString:@"off"] || [mode isEqualToString:@"disabled"]) {
        _mode = FLUModeDisabled;
        _enabled = NO;
    } else {
        _mode = FLUModeJustNow;
    }

    _fixedDate = nil;
    id raw = d[@"FixedDate"];
    if ([raw isKindOfClass:[NSDate class]]) {
        _fixedDate = raw;
    } else if ([raw isKindOfClass:[NSString class]]) {
        NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
        _fixedDate = [iso dateFromString:raw];
        if (!_fixedDate) {
            NSDateFormatter *f = [[NSDateFormatter alloc] init];
            f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            f.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            _fixedDate = [f dateFromString:raw];
        }
    }
    if (!_fixedDate) {
        // default fixed: 2020-01-01
        _fixedDate = [NSDate dateWithTimeIntervalSince1970:1577836800];
    }
}

- (BOOL)enabled { return _enabled && _mode != FLUModeDisabled; }
- (FLUMode)mode { return _mode; }
- (NSDate *)fixedDate { return _fixedDate; }
- (BOOL)debugLogging { return _debugLogging; }

- (NSString *)justNowString {
    // Prefer system-localized if available; fallback RU/EN
    return NSLocalizedStringFromTableInBundle(
        @"Just Now", @"Localizable", [NSBundle mainBundle], @"Just Now") ?: @"Только что";
}

- (NSString *)neverUsedString {
    return NSLocalizedStringFromTableInBundle(
        @"Never Used", @"Localizable", [NSBundle mainBundle], @"Never Used") ?: @"Не использовалось";
}

@end
