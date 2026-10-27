#import "FLURootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString * const FLUPreferencesPath = @"/var/jb/var/mobile/Library/Preferences/com.storagefake.lastused.plist";
static CFStringRef const FLUReloadNotification = CFSTR("com.storagefake.lastused/Reload");

static NSDictionary *FLUReadSettings(void) {
    return [NSDictionary dictionaryWithContentsOfFile:FLUPreferencesPath] ?: @{};
}

static void FLUPostReload(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), FLUReloadNotification, NULL, NULL, YES);
}

static NSDate *FLUDateFromSetting(id raw) {
    if ([raw isKindOfClass:[NSDate class]]) return raw;
    if (![raw isKindOfClass:[NSString class]]) return nil;
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    return [formatter dateFromString:raw];
}

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
    if (@available(iOS 13.4, *)) self.datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    self.datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.datePicker];
    [NSLayoutConstraint activateConstraints:@[
        [self.datePicker.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.datePicker.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.datePicker.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Сохранить" style:UIBarButtonItemStyleDone target:self action:@selector(saveDate)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Отмена" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    id raw = FLUReadSettings()[@"FixedDate"];
    self.datePicker.date = FLUDateFromSetting(raw) ?: [NSDate date];
    self.datePicker.maximumDate = [NSDate date];
}
- (void)saveDate {
    NSMutableDictionary *settings = [FLUReadSettings() mutableCopy];
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    settings[@"FixedDate"] = [formatter stringFromDate:self.datePicker.date];
    if (![settings writeToFile:FLUPreferencesPath atomically:YES]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ошибка" message:@"Не удалось сохранить дату. Проверьте права доступа к файлу настроек." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    FLUPostReload();
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)cancel { [self.navigationController popViewControllerAnimated:YES]; }
@end

@interface FLUAppDateEditorController : UIViewController
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) UIDatePicker *datePicker;
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

@implementation FLUAppDateEditorController
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier {
    self = [super init];
    if (self) _bundleIdentifier = [bundleIdentifier copy];
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.bundleIdentifier;
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *modeLabel = [[UILabel alloc] init];
    modeLabel.text = @"Режим для этого приложения";
    modeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    modeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:modeLabel];

    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"Сейчас", @"Не использ.", @"Дата"]];
    self.modeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.modeControl];

    UILabel *dateLabel = [[UILabel alloc] init];
    dateLabel.text = @"Фиксированная дата";
    dateLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:dateLabel];

    self.datePicker = [[UIDatePicker alloc] init];
    self.datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    if (@available(iOS 13.4, *)) self.datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    self.datePicker.maximumDate = [NSDate date];
    self.datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.datePicker];

    [NSLayoutConstraint activateConstraints:@[
        [modeLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [modeLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [modeLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.modeControl.topAnchor constraintEqualToAnchor:modeLabel.bottomAnchor constant:12],
        [self.modeControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.modeControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [dateLabel.topAnchor constraintEqualToAnchor:self.modeControl.bottomAnchor constant:28],
        [dateLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [dateLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.datePicker.topAnchor constraintEqualToAnchor:dateLabel.bottomAnchor constant:8],
        [self.datePicker.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.datePicker.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    NSDictionary *settings = FLUReadSettings();
    NSDictionary *apps = [settings[@"AppDates"] isKindOfClass:[NSDictionary class]] ? settings[@"AppDates"] : @{};
    NSDictionary *entry = [apps[self.bundleIdentifier] isKindOfClass:[NSDictionary class]] ? apps[self.bundleIdentifier] : @{};
    NSString *mode = [entry[@"Mode"] description].lowercaseString ?: @"fixed";
    if ([mode isEqualToString:@"justnow"]) self.modeControl.selectedSegmentIndex = 0;
    else if ([mode isEqualToString:@"never"]) self.modeControl.selectedSegmentIndex = 1;
    else self.modeControl.selectedSegmentIndex = 2;
    self.datePicker.date = FLUDateFromSetting(entry[@"Date"]) ?: FLUDateFromSetting(settings[@"FixedDate"]) ?: [NSDate date];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Сохранить" style:UIBarButtonItemStyleDone target:self action:@selector(save)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Удалить" style:UIBarButtonItemStylePlain target:self action:@selector(removeOverride)];
}
- (BOOL)writeApps:(NSDictionary *)apps {
    NSMutableDictionary *settings = [FLUReadSettings() mutableCopy];
    settings[@"AppDates"] = apps;
    if (![settings writeToFile:FLUPreferencesPath atomically:YES]) return NO;
    FLUPostReload();
    return YES;
}
- (void)save {
    NSDictionary *existingApps = FLUReadSettings()[@"AppDates"];
    NSMutableDictionary *apps = [existingApps isKindOfClass:[NSDictionary class]] ? [existingApps mutableCopy] : [NSMutableDictionary new];
    NSString *mode = self.modeControl.selectedSegmentIndex == 0 ? @"justnow" : (self.modeControl.selectedSegmentIndex == 1 ? @"never" : @"fixed");
    NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
    apps[self.bundleIdentifier] = @{@"Mode": mode, @"Date": [formatter stringFromDate:self.datePicker.date]};
    if (![self writeApps:apps]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ошибка" message:@"Не удалось сохранить индивидуальные настройки." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)removeOverride {
    NSDictionary *existingApps = FLUReadSettings()[@"AppDates"];
    NSMutableDictionary *apps = [existingApps isKindOfClass:[NSDictionary class]] ? [existingApps mutableCopy] : [NSMutableDictionary new];
    [apps removeObjectForKey:self.bundleIdentifier];
    if (![self writeApps:apps]) return;
    [self.navigationController popViewControllerAnimated:YES];
}
@end

@interface FLUAppDatesController : UITableViewController
@property (nonatomic, copy) NSArray<NSString *> *bundleIdentifiers;
@end

@implementation FLUAppDatesController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Индивидуальные даты";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addApp)];
    [self reloadApps];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadApps];
}
- (void)reloadApps {
    NSDictionary *apps = FLUReadSettings()[@"AppDates"];
    NSArray *keys = [apps isKindOfClass:[NSDictionary class]] ? [apps allKeys] : @[];
    self.bundleIdentifiers = [keys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.bundleIdentifiers.count + 1; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppDateCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AppDateCell"];
    if (indexPath.row == self.bundleIdentifiers.count) {
        cell.textLabel.text = @"Добавить приложение по Bundle ID…";
        cell.detailTextLabel.text = @"Например, com.example.app";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSString *bundleID = self.bundleIdentifiers[indexPath.row];
        NSDictionary *entry = FLUReadSettings()[@"AppDates"][bundleID];
        NSString *mode = [entry[@"Mode"] description];
        NSString *modeText = [mode isEqualToString:@"never"] ? @"Не использовалось" : ([mode isEqualToString:@"justnow"] ? @"Только что" : @"Фиксированная дата");
        cell.textLabel.text = bundleID;
        cell.detailTextLabel.text = modeText;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == self.bundleIdentifiers.count) { [self addApp]; return; }
    NSString *bundleID = self.bundleIdentifiers[indexPath.row];
    FLUAppDateEditorController *editor = [[FLUAppDateEditorController alloc] initWithBundleIdentifier:bundleID];
    [self.navigationController pushViewController:editor animated:YES];
}
- (void)addApp {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Добавить приложение" message:@"Введи Bundle ID приложения. Его можно посмотреть в сведениях о приложении или в списке установленных пакетов." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"com.example.app";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.keyboardType = UIKeyboardTypeURL;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Продолжить" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *bundleID = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (bundleID.length == 0 || [bundleID containsString:@" "]) {
            UIAlertController *error = [UIAlertController alertControllerWithTitle:@"Некорректный Bundle ID" message:@"Укажи идентификатор приложения, например com.example.app." preferredStyle:UIAlertControllerStyleAlert];
            [error addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:error animated:YES completion:nil];
            return;
        }
        FLUAppDateEditorController *editor = [[FLUAppDateEditorController alloc] initWithBundleIdentifier:bundleID];
        [self.navigationController pushViewController:editor animated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@implementation FLURootListController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = @"FakeLastUsed";
}
- (void)chooseFixedDate:(PSSpecifier *)specifier {
    [self.navigationController pushViewController:[[FLUDatePickerController alloc] init] animated:YES];
}
- (void)manageAppDates:(PSSpecifier *)specifier {
    [self.navigationController pushViewController:[[FLUAppDatesController alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES];
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *settings = FLUReadSettings();
    id key = [specifier propertyForKey:@"key"];
    return key ? (settings[key] ?: [specifier propertyForKey:@"default"]) : [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *settings = [FLUReadSettings() mutableCopy];
    id key = [specifier propertyForKey:@"key"];
    if (key) {
        if (value) settings[key] = value;
        else [settings removeObjectForKey:key];
        [settings writeToFile:FLUPreferencesPath atomically:YES];
    }
    CFStringRef notif = (__bridge CFStringRef)[specifier propertyForKey:@"PostNotification"];
    if (notif) CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notif, NULL, NULL, YES);
}
@end
