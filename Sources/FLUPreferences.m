#import "FLUPreferences.h"

static NSString * const kPath = @"/var/jb/var/mobile/Library/Preferences/com.storagefake.lastused.plist";

static NSDate *FLUDateFromValue(id raw) {
    if ([raw isKindOfClass:[NSDate class]]) return raw;
    if (![raw isKindOfClass:[NSString class]]) return nil;
    NSISO8601DateFormatter *iso = [[NSISO8601DateFormatter alloc] init];
    NSDate *date = [iso dateFromString:raw];
    if (!date) {
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        f.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        date = [f dateFromString:raw];
    }
    return date;
}

static FLUMode FLUModeFromValue(id raw, FLUMode fallback) {
    NSString *mode = [[raw description] lowercaseString];
    if ([mode isEqualToString:@"never"] || [mode isEqualToString:@"neverused"]) return FLUModeNeverUsed;
    if ([mode isEqualToString:@"fixed"] || [mode isEqualToString:@"custom"]) return FLUModeFixedDate;
    if ([mode isEqualToString:@"off"] || [mode isEqualToString:@"disabled"]) return FLUModeDisabled;
    if ([mode isEqualToString:@"justnow"] || [mode isEqualToString:@"now"]) return FLUModeJustNow;
    return fallback;
}

@implementation FLUPreferences {
    BOOL _enabled;
    FLUMode _mode;
    NSDate *_fixedDate;
    BOOL _debugLogging;
    NSDictionary<NSString *, NSDictionary *> *_appDates;
    NSString *_listMode;
    NSSet<NSString *> *_blacklist;
    NSSet<NSString *> *_whitelist;
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
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kPath] ?: @{};
    _enabled = d[@"Enabled"] ? [d[@"Enabled"] boolValue] : YES;
    _debugLogging = d[@"DebugLogging"] ? [d[@"DebugLogging"] boolValue] : NO;
    // Global default mode is removed; apps without an override use “just now”.
    _mode = FLUModeJustNow;
    if (_mode == FLUModeDisabled) _enabled = NO;

    // Fixed dates are configured per app only.
    _fixedDate = nil;
    if (!_fixedDate) _fixedDate = [NSDate dateWithTimeIntervalSince1970:1577836800];

    id appDates = d[@"AppDates"];
    _appDates = [appDates isKindOfClass:[NSDictionary class]] ? [appDates copy] : @{};

    NSString *listMode = [d[@"ListMode"] isKindOfClass:[NSString class]] ? d[@"ListMode"] : @"all";
    _listMode = [@[@"all", @"blacklist", @"whitelist"] containsObject:listMode] ? [listMode copy] : @"all";
    id black = d[@"Blacklist"];
    id white = d[@"Whitelist"];
    _blacklist = [black isKindOfClass:[NSArray class]] ? [NSSet setWithArray:black] : [NSSet set];
    _whitelist = [white isKindOfClass:[NSArray class]] ? [NSSet setWithArray:white] : [NSSet set];
}

- (BOOL)enabled { return _enabled && _mode != FLUModeDisabled; }
- (FLUMode)mode { return _mode; }
- (NSDate *)fixedDate { return _fixedDate; }
- (BOOL)debugLogging { return _debugLogging; }
- (NSString *)listMode { return _listMode; }
- (NSSet<NSString *> *)blacklist { return _blacklist; }
- (NSSet<NSString *> *)whitelist { return _whitelist; }
- (NSDictionary<NSString *,NSDictionary *> *)appDates { return _appDates; }

- (BOOL)shouldSpoofBundleIdentifier:(NSString *)bundleIdentifier {
    if (!_enabled || _mode == FLUModeDisabled) return NO;
    if ([_listMode isEqualToString:@"blacklist"]) {
        if (bundleIdentifier.length == 0) return NO;
        return ![_blacklist containsObject:bundleIdentifier];
    }
    if ([_listMode isEqualToString:@"whitelist"]) {
        if (bundleIdentifier.length == 0) return NO;
        return [_whitelist containsObject:bundleIdentifier];
    }
    return YES;
}

- (BOOL)hasOverrideForBundleIdentifier:(NSString *)bundleIdentifier {
    if (bundleIdentifier.length == 0) return NO;
    return [_appDates[bundleIdentifier] isKindOfClass:[NSDictionary class]];
}

- (FLUMode)modeForBundleIdentifier:(NSString *)bundleIdentifier {
    NSDictionary *entry = bundleIdentifier.length ? _appDates[bundleIdentifier] : nil;
    if (![entry isKindOfClass:[NSDictionary class]]) return _mode;
    return FLUModeFromValue(entry[@"Mode"], _mode);
}

- (NSDate *)fixedDateForBundleIdentifier:(NSString *)bundleIdentifier {
    NSDictionary *entry = bundleIdentifier.length ? _appDates[bundleIdentifier] : nil;
    NSDate *date = [entry isKindOfClass:[NSDictionary class]] ? FLUDateFromValue(entry[@"Date"]) : nil;
    return date ?: _fixedDate;
}

- (NSString *)justNowString {
    return NSLocalizedStringFromTableInBundle(@"Just Now", @"Localizable", [NSBundle mainBundle], @"Just Now") ?: @"Только что";
}

- (NSString *)neverUsedString {
    return NSLocalizedStringFromTableInBundle(@"Never Used", @"Localizable", [NSBundle mainBundle], @"Never Used") ?: @"Не использовалось";
}

@end
