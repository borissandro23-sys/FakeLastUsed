/*
 FakeLastUsed — spoof Last Used / Never Used in Settings → iPhone Storage (iOS 15).

 IMPORTANT: Method names below are common patterns for Storage UI. On iOS 15.8.x
 verify with FLEX / class-dump of StorageSettings / Preferences and adjust hooks.
 Soft-fail: if classes are missing, tweak does nothing.
*/

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>
#import "Sources/FLUPreferences.h"

static void FLULog(NSString *fmt, ...) {
    if (![FLUPreferences shared].debugLogging) return;
    va_list a;
    va_start(a, fmt);
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
            return nil;

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
            return @"Только что";

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

// C callback вместо C++-лямбды: Tweak.x компилируется через Logos.
static void FLUHandlePrefsReload(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
) {
    [[FLUPreferences shared] reload];
}

%ctor {
    [[FLUPreferences shared] reload];

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        FLUHandlePrefsReload,
        CFSTR("com.storagefake.lastused/Reload"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );

    FLULog(@"loaded");
}

// --- Date-based hooks (preferred) ----------------------------------------

%hook STStorageApp

- (NSDate *)lastUsedDate {
    if ([FLUPreferences shared].enabled) {
        NSDate *spoof = FLUSpoofedDate();
        FLULog(@"STStorageApp lastUsedDate spoof=%@", spoof);
        return spoof;
    }
    return %orig;
}

- (NSDate *)lastUsed {
    if ([FLUPreferences shared].enabled) {
        return FLUSpoofedDate();
    }
    return %orig;
}

%end

// Some builds use PSStorageApp / private app records

%hook PSStorageApp

- (NSDate *)lastUsedDate {
    if ([FLUPreferences shared].enabled) {
        return FLUSpoofedDate();
    }
    return %orig;
}

%end

// --- String-based hooks (fallback when UI already formatted) -------------

%hook STStorageAppCell

- (NSString *)lastUsedString {
    NSString *original = %orig;

    if ([FLUPreferences shared].enabled) {
        return FLUSpoofedString(original);
    }

    return original;
}

- (NSString *)sizeAndLastUsedString {
    NSString *original = %orig;

    if (![FLUPreferences shared].enabled) {
        return original;
    }

    // Best-effort: replacing the trailing last-used portion is fragile.
    // Prefer date hooks when available.
    return original;
}

%end

// Reload preferences when Preferences becomes active.

%hook PreferencesAppController

- (void)applicationDidBecomeActive:(id)app {
    %orig;
    [[FLUPreferences shared] reload];
}

%end
