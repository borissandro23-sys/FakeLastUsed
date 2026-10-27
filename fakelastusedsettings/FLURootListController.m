#import "FLURootListController.h"
#import <Preferences/PSSpecifier.h>

@implementation FLURootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = @"FakeLastUsed";
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *path = @"/var/jb/var/mobile/Library/Preferences/com.storagefake.lastused.plist";
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
    id key = [specifier propertyForKey:@"key"];
    if (!key) return [specifier propertyForKey:@"default"];
    return settings[key] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = @"/var/jb/var/mobile/Library/Preferences/com.storagefake.lastused.plist";
    NSMutableDictionary *settings = [[NSDictionary dictionaryWithContentsOfFile:path] mutableCopy] ?: [NSMutableDictionary new];
    id key = [specifier propertyForKey:@"key"];
    if (key) {
        if (value) settings[key] = value;
        else [settings removeObjectForKey:key];
        [settings writeToFile:path atomically:YES];
    }
    CFStringRef notif = (__bridge CFStringRef)[specifier propertyForKey:@"PostNotification"];
    if (notif) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notif, NULL, NULL, YES);
    }
}

@end
