#import "FLURootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>

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
@property (nonatomic, strong) UIButton *keepTimeButton;
@property (nonatomic, assign) BOOL keepTime;
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

    self.keepTimeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.keepTimeButton setTitle:@"Не менять дату и время: выкл." forState:UIControlStateNormal];
    self.keepTimeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.keepTimeButton addTarget:self action:@selector(toggleKeepTime) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.keepTimeButton];

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
        [self.datePicker.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.keepTimeButton.topAnchor constraintEqualToAnchor:self.datePicker.bottomAnchor constant:8],
        [self.keepTimeButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
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
- (void)toggleKeepTime {
    self.keepTime = !self.keepTime;
    [self.keepTimeButton setTitle:(self.keepTime ? @"Не менять дату и время: вкл." : @"Не менять дату и время: выкл.") forState:UIControlStateNormal];
    self.datePicker.enabled = !self.keepTime;
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
    NSDate *dateToSave = self.datePicker.date;
    if (self.keepTime) {
        NSDictionary *oldEntry = [existingApps isKindOfClass:[NSDictionary class]] ? existingApps[self.bundleIdentifier] : nil;
        dateToSave = FLUDateFromSetting(oldEntry[@"Date"]) ?: FLUDateFromSetting(FLUReadSettings()[@"FixedDate"]) ?: [NSDate date];
    }
    apps[self.bundleIdentifier] = @{@"Mode": mode, @"Date": [formatter stringFromDate:dateToSave]};
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

@interface FLUAppDatesController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<NSDictionary *> *allApps;
@property (nonatomic, copy) NSArray<NSDictionary *> *visibleApps;
@property (nonatomic, strong) UISearchController *searchController;
@end

static NSArray<NSDictionary *> *FLUInstalledApps(void) {
    NSMutableArray<NSDictionary *> *result = [NSMutableArray new];
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
    SEL allAppsSelector = NSSelectorFromString(@"allInstalledApplications");
    if (!workspaceClass || ![workspaceClass respondsToSelector:defaultWorkspaceSelector]) return result;
    id workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, defaultWorkspaceSelector);
    if (![workspace respondsToSelector:allAppsSelector]) return result;
    id installed = ((id (*)(id, SEL))objc_msgSend)(workspace, allAppsSelector);
    for (id proxy in installed) {
        NSString *bundleID = nil;
        NSString *name = nil;
        UIImage *icon = nil;
        SEL idSelector = NSSelectorFromString(@"applicationIdentifier");
        SEL nameSelector = NSSelectorFromString(@"localizedName");
        SEL iconSelector = NSSelectorFromString(@"iconDataForVariant:");
        if ([proxy respondsToSelector:idSelector]) bundleID = ((id (*)(id, SEL))objc_msgSend)(proxy, idSelector);
        if ([proxy respondsToSelector:nameSelector]) name = ((id (*)(id, SEL))objc_msgSend)(proxy, nameSelector);
        if ([proxy respondsToSelector:iconSelector]) {
            NSData *iconData = ((id (*)(id, SEL, NSInteger))objc_msgSend)(proxy, iconSelector, 2);
            if (![iconData isKindOfClass:[NSData class]] || iconData.length == 0)
                iconData = ((id (*)(id, SEL, NSInteger))objc_msgSend)(proxy, iconSelector, 0);
            if ([iconData isKindOfClass:[NSData class]]) icon = [UIImage imageWithData:iconData];
        }
        if (bundleID.length) {
            NSMutableDictionary *app = [@{@"id": bundleID, @"name": name.length ? name : bundleID} mutableCopy];
            if (icon) app[@"icon"] = icon;
            [result addObject:app];
        }
    }
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
    return result;
}

@implementation FLUAppDatesController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Выбрать приложение";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Поиск приложения";
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addApp)];
    [self reloadApps];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadApps];
}
- (void)reloadApps {
    self.allApps = FLUInstalledApps();
    self.visibleApps = self.allApps;
    [self updateSearchResultsForSearchController:self.searchController];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text ?: @"";
    if (query.length == 0) self.visibleApps = self.allApps;
    else self.visibleApps = [self.allApps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *app, NSDictionary *bindings) {
        return [app[@"name"] localizedCaseInsensitiveContainsString:query] || [app[@"id"] localizedCaseInsensitiveContainsString:query];
    }]];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.visibleApps.count + 1; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppDateCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AppDateCell"];
    if (indexPath.row == self.visibleApps.count) {
        cell.textLabel.text = @"Ввести Bundle ID вручную…";
        cell.detailTextLabel.text = @"Если приложение не появилось в списке";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    NSDictionary *app = self.visibleApps[indexPath.row];
    cell.textLabel.text = app[@"name"];
    cell.detailTextLabel.text = app[@"id"];
    cell.imageView.image = [app[@"icon"] isKindOfClass:[UIImage class]] ? app[@"icon"] : nil;
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    cell.imageView.layer.cornerRadius = 8.0;
    cell.imageView.clipsToBounds = YES;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == self.visibleApps.count) { [self addApp]; return; }
    NSString *bundleID = self.visibleApps[indexPath.row][@"id"];
    FLUAppDateEditorController *editor = [[FLUAppDateEditorController alloc] initWithBundleIdentifier:bundleID];
    [self.navigationController pushViewController:editor animated:YES];
}
- (void)addApp {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Добавить приложение" message:@"Введи Bundle ID приложения." preferredStyle:UIAlertControllerStyleAlert];
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
