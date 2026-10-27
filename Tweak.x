/*
 FakeLastUsed — spoof Last Used / Never Used in Settings → iPhone Storage (iOS 15).
*/
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>
#import "Sources/FLUPreferences.h"

static void FLULog(NSString *fmt, ...) {
    if (![FLUPreferences shared].debugLogging) return;
    va_list a; va_start(a, fmt);
    NSLogv([@"[FakeLastUsed] " stringByAppendingString:fmt], a);
    va_end(a);
}

static NSString *FLUBundleIdentifier(id object) {
    if (!object || object == [NSNull null]) return nil;
    NSArray *keys = @[@"bundleIdentifier", @"applicationIdentifier", @"bundleID", @"bundleId"];
    for (NSString *key in keys) {
        @try {
            id value = [object valueForKey:key];
            if ([value isKindOfClass:[NSString class]] && [value length] > 0) return value;
        } @catch (__unused NSException *exception) {}
    }
    // A storage cell may contain the actual app record.
    for (NSString *key in @[@"storageApp", @"app", @"representedObject"]) {
        @try {
            id nested = [object valueForKey:key];
            if (nested && nested != object) {
                NSString *value = FLUBundleIdentifier(nested);
                if (value.length) return value;
            }
        } @catch (__unused NSException *exception) {}
    }
    return nil;
}

static FLUMode FLUModeForObject(id object) {
    FLUPreferences *p = [FLUPreferences shared];
    return [p modeForBundleIdentifier:FLUBundleIdentifier(object)];
}

static NSDate *FLUSpoofedDate(id object) {
    FLUPreferences *p = [FLUPreferences shared];
    if (![p shouldSpoofBundleIdentifier:FLUBundleIdentifier(object)]) return nil;
    switch (FLUModeForObject(object)) {
        case FLUModeJustNow: return [NSDate date];
        case FLUModeNeverUsed: return nil;
        case FLUModeFixedDate: return [p fixedDateForBundleIdentifier:FLUBundleIdentifier(object)];
        default: return nil;
    }
}

static NSString *FLUSpoofedString(NSString *orig, id object) {
    FLUPreferences *p = [FLUPreferences shared];
    if (![p shouldSpoofBundleIdentifier:FLUBundleIdentifier(object)]) return orig;
    switch (FLUModeForObject(object)) {
        case FLUModeJustNow: return @"Только что";
        case FLUModeNeverUsed: return @"Не использовалось";
        case FLUModeFixedDate: {
            NSDateFormatter *f = [[NSDateFormatter alloc] init];
            f.dateStyle = NSDateFormatterMediumStyle;
            f.timeStyle = NSDateFormatterNoStyle;
            f.locale = [NSLocale currentLocale];
            return [f stringFromDate:[p fixedDateForBundleIdentifier:FLUBundleIdentifier(object)]] ?: orig;
        }
        default: return orig;
    }
}

static void FLUHandlePrefsReload(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[FLUPreferences shared] reload];
}

%ctor {
    [[FLUPreferences shared] reload];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, FLUHandlePrefsReload,
        CFSTR("com.storagefake.lastused/Reload"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    FLULog(@"loaded");
}

%hook STStorageApp
- (NSDate *)lastUsedDate {
    if ([[FLUPreferences shared] shouldSpoofBundleIdentifier:FLUBundleIdentifier(self)]) return FLUSpoofedDate(self);
    return %orig;
}
- (NSDate *)lastUsed {
    if ([FLUPreferences shared].enabled) return FLUSpoofedDate(self);
    return %orig;
}
%end

%hook PSStorageApp
- (NSDate *)lastUsedDate {
    if ([FLUPreferences shared].enabled) return FLUSpoofedDate(self);
    return %orig;
}
%end

%hook STStorageAppCell
- (NSString *)lastUsedString {
    NSString *original = %orig;
    if ([[FLUPreferences shared] shouldSpoofBundleIdentifier:FLUBundleIdentifier(self)]) return FLUSpoofedString(original, self);
    return original;
}
- (NSString *)sizeAndLastUsedString {
    NSString *original = %orig;
    if (![FLUPreferences shared].enabled) return original;
    return original;
}
%end

%hook PreferencesAppController
- (void)applicationDidBecomeActive:(id)app {
    %orig;
    [[FLUPreferences shared] reload];
}
%end
