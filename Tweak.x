/*
 FakeLastUsed — spoof Last Used / Never Used in Settings → iPhone Storage (iOS 15).

 IMPORTANT: Method names below are common patterns for Storage UI. On iOS 15.8.x
 verify with FLEX / class-dump of StorageSettings / Preferences and adjust hooks.
 Soft-fail: if classes are missing, tweak does nothing.
*/

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Sources/FLUPreferences.h"

static void FLULog(NSString *fmt, ...) {
    if (![FLUPreferences shared].debugLogging) return;
    va_list a; va_start(a, fmt);
    NSLogv([@"[FakeLastUsed] " stringByAppendingString:fmt], a);
    va_end(a);
}

static NSDate *FLUSpoofedDate(void) {
    FLUPreferences *p = [FLUPreferences shared];
    if (!p.enabled) return nil;
    switch (p.mode) {
        case FLUModeJustNow:
            return [NSDate date];
        case FLUModeNeverUsed:
            return nil; // many UIs map nil → "Never Used"
        case FLUModeFixedDate:
            return p.fixedDate;
        default:
            return nil;
    }
}

static NSString *FLUSpoofedString(NSString *orig) {
    FLUPreferences *p = [FLUPreferences shared];
    if (!p.enabled) return orig;
    switch (p.mode) {
        case FLUModeJustNow:
            return @"Только что"; // Storage often uses its own formatter; string hooks help when present
        case FLUModeNeverUsed:
            return @"Не использовалось";
        case FLUModeFixedDate: {
            NSDateFormatter *f = [[NSDateFormatter alloc] init];
            f.dateStyle = NSDateFormatterMediumStyle;
            f.timeStyle = NSDateFormatterNoStyle;
            f.locale = [NSLocale currentLocale];
            return [f stringFromDate:p.fixedDate] ?: orig;
        }
        default:
            return orig;
    }
}

%ctor {
    [[FLUPreferences shared] reload];
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        (CFNotificationCallback)(+[](CFNotificationCenterRef, void *, CFStringRef, const void *, CFDictionaryRef) {
            [[FLUPreferences shared] reload];
        }),
        CFSTR("com.storagefake.lastused/Reload"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);
    FLULog(@"loaded");
}

// --- Date-based hooks (preferred) ----------------------------------------

%hook STStorageApp
- (NSDate *)lastUsedDate {
    NSDate *spoof = FLUSpoofedDate();
    if ([FLUPreferences shared].enabled) {
        FLULog(@"STStorageApp lastUsedDate spoof=%@", spoof);
        return spoof; // nil = never for many code paths
    }
    return %orig;
}
- (NSDate *)lastUsed {
    NSDate *spoof = FLUSpoofedDate();
    if ([FLUPreferences shared].enabled) {
        return spoof;
    }
    return %orig;
}
%end

// Some builds use PSStorageApp / private app records
%hook PSStorageApp
- (NSDate *)lastUsedDate {
    if ([FLUPreferences shared].enabled) return FLUSpoofedDate();
    return %orig;
}
%end

// --- String-based hooks (fallback when UI already formatted) -------------

%hook STStorageAppCell
- (NSString *)lastUsedString {
    if ([FLUPreferences shared].enabled) return FLUSpoofedString(%orig);
    return %orig;
}
- (NSString *)sizeAndLastUsedString {
    NSString *o = %orig;
    if (![FLUPreferences shared].enabled) return o;
    // Best-effort: replace trailing last-used portion is fragile; prefer date hooks.
    return o;
}
%end

// Generic: if a method named *lastUsed* returns NSString on storage classes
// (device-specific — enable after confirming with class-dump)

// Reload prefs when Preferences becomes active
%hook PreferencesAppController
- (void)applicationDidBecomeActive:(id)app {
    %orig;
    [[FLUPreferences shared] reload];
}
%end
