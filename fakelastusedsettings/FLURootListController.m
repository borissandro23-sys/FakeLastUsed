#import "FLURootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

static NSString * const FLUPreferencesPath = @"/var/jb/var/mobile/Library/Preferences/com.storagefake.lastused.plist";
static CFStringRef const FLUReloadNotification = CFSTR("com.storagefake.lastused/Reload");

@interface FLUDatePickerController : UIViewController
@property (nonatomic, strong) UIDatePicker *datePicker;
@end

@implementation FLUDatePickerController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Дата последнего использования";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.datePicker = [[UIDatePicker alloc] init];
    self.datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    if (@available(iOS 13.4, *)) {
        self.datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    }
    self.datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.datePicker];

    [NSLayoutConstraint activateConstraints:@[
        [self.datePicker.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.datePicker.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.datePicker.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Сохранить"
        style:UIBarButtonItemStyleDone
        target:self
        action:@selector(saveDate)];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Отмена"
        style:UIBarButtonItemStylePlain
        target:self
        action:@selector(cancel)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:FLUPreferencesPath] ?: @{};
    id raw = settings[@"FixedDate"];
    NSDate *date = nil;
    if ([raw isKindOfClass:[NSDate class]]) {
        date = raw;
    } else if ([raw isKindOfClass:[NSString class]]) {
        NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
        date = [formatter dateFromString:raw];
    }
    self.datePicker.date = date ?: [NSDate date];
    self.datePicker.maximumDate = [NSDate date];
}

- (void)saveDate {
    NSMutableDictionary *settings = [[NSDictionary dictionaryWithContentsOfFile:FLUPreferencesPath] mutableCopy] ?: [NSMutableDictionary new];
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    settings[@"FixedDate"] = [formatter stringFromDate:self.datePicker.date];
    if (![settings writeToFile:FLUPreferencesPath atomically:YES]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ошибка" message:@"Не удалось сохранить дату. Проверьте права доступа к файлу настроек." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), FLUReloadNotification, NULL, NULL, YES);
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)cancel {
    [self.navigationController popViewControllerAnimated:YES];
}

@end

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

- (void)chooseFixedDate:(PSSpecifier *)specifier {
    FLUDatePickerController *controller = [[FLUDatePickerController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:FLUPreferencesPath] ?: @{};
    id key = [specifier propertyForKey:@"key"];
    if (!key) return [specifier propertyForKey:@"default"];
    return settings[key] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *settings = [[NSDictionary dictionaryWithContentsOfFile:FLUPreferencesPath] mutableCopy] ?: [NSMutableDictionary new];
    id key = [specifier propertyForKey:@"key"];
    if (key) {
        if (value) settings[key] = value;
        else [settings removeObjectForKey:key];
        [settings writeToFile:FLUPreferencesPath atomically:YES];
    }
    CFStringRef notif = (__bridge CFStringRef)[specifier propertyForKey:@"PostNotification"];
    if (notif) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notif, NULL, NULL, YES);
    }
}

@end
