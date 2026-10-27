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

@interface FLUAppDateEditorController : UIViewController
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UIDatePicker *timePicker;
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

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];
    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:contentView];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [contentView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor]
    ]];

    UILabel *modeLabel = [[UILabel alloc] init];
    modeLabel.text = @"Режим для этого приложения";
    modeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    modeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:modeLabel];

    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"Сейчас", @"Не использ.", @"Дата"]];
    self.modeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.modeControl];

    UILabel *dateLabel = [[UILabel alloc] init];
    dateLabel.text = @"Фиксированная дата";
    dateLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:dateLabel];

    self.datePicker = [[UIDatePicker alloc] init];
    self.datePicker.datePickerMode = UIDatePickerModeDate;
    if (@available(iOS 14.0, *)) {
        self.datePicker.preferredDatePickerStyle = UIDatePickerStyleInline;
    } else if (@available(iOS 13.4, *)) {
        self.datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    }
    self.datePicker.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"ru_RU"];
    self.datePicker.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    self.datePicker.maximumDate = nil;
    self.datePicker.minimumDate = nil;
    self.datePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.datePicker];

    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.text = @"Время";
    timeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:timeLabel];

    self.timePicker = [[UIDatePicker alloc] init];
    self.timePicker.datePickerMode = UIDatePickerModeTime;
    if (@available(iOS 13.4, *)) self.timePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    self.timePicker.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"ru_RU"];
    self.timePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.timePicker];

    self.keepTimeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.keepTimeButton setTitle:@"Не менять дату и время: выкл." forState:UIControlStateNormal];
    self.keepTimeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.keepTimeButton addTarget:self action:@selector(toggleKeepTime) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:self.keepTimeButton];

    [NSLayoutConstraint activateConstraints:@[
        [modeLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:24],
        [modeLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [modeLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [self.modeControl.topAnchor constraintEqualToAnchor:modeLabel.bottomAnchor constant:12],
        [self.modeControl.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [self.modeControl.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [dateLabel.topAnchor constraintEqualToAnchor:self.modeControl.bottomAnchor constant:28],
        [dateLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [dateLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [self.datePicker.topAnchor constraintEqualToAnchor:dateLabel.bottomAnchor constant:8],
        [self.datePicker.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:8],
        [self.datePicker.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-8],
        [timeLabel.topAnchor constraintEqualToAnchor:self.datePicker.bottomAnchor constant:12],
        [timeLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [timeLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [self.timePicker.topAnchor constraintEqualToAnchor:timeLabel.bottomAnchor constant:4],
        [self.timePicker.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.timePicker.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [self.keepTimeButton.topAnchor constraintEqualToAnchor:self.timePicker.bottomAnchor constant:8],
        [self.keepTimeButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.keepTimeButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24]
    ]];

    NSDictionary *settings = FLUReadSettings();
    NSDictionary *apps = [settings[@"AppDates"] isKindOfClass:[NSDictionary class]] ? settings[@"AppDates"] : @{};
    NSDictionary *entry = [apps[self.bundleIdentifier] isKindOfClass:[NSDictionary class]] ? apps[self.bundleIdentifier] : @{};
    NSString *mode = [entry[@"Mode"] description].lowercaseString ?: @"fixed";
    if ([mode isEqualToString:@"justnow"]) self.modeControl.selectedSegmentIndex = 0;
    else if ([mode isEqualToString:@"never"]) self.modeControl.selectedSegmentIndex = 1;
    else self.modeControl.selectedSegmentIndex = 2;
    NSDate *initialDate = FLUDateFromSetting(entry[@"Date"]) ?: [NSDate date];
    self.datePicker.date = initialDate;
    self.timePicker.date = initialDate;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Сохранить" style:UIBarButtonItemStyleDone target:self action:@selector(save)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Удалить" style:UIBarButtonItemStylePlain target:self action:@selector(removeOverride)];
}
- (void)toggleKeepTime {
    self.keepTime = !self.keepTime;
    [self.keepTimeButton setTitle:(self.keepTime ? @"Не менять дату и время: вкл." : @"Не менять дату и время: выкл.") forState:UIControlStateNormal];
    self.datePicker.enabled = !self.keepTime;
    self.timePicker.enabled = !self.keepTime;
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
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponents = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:self.datePicker.date];
    NSDateComponents *timeComponents = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:self.timePicker.date];
    dateComponents.hour = timeComponents.hour;
    dateComponents.minute = timeComponents.minute;
    dateComponents.second = timeComponents.second;
    dateToSave = [calendar dateFromComponents:dateComponents] ?: dateToSave;
    if (self.keepTime) {
        NSDictionary *oldEntry = [existingApps isKindOfClass:[NSDictionary class]] ? existingApps[self.bundleIdentifier] : nil;
        dateToSave = FLUDateFromSetting(oldEntry[@"Date"]) ?: [NSDate date];
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
        SEL iconOptionsSelector = NSSelectorFromString(@"iconDataForVariant:withOptions:");
        if ([proxy respondsToSelector:idSelector]) bundleID = ((id (*)(id, SEL))objc_msgSend)(proxy, idSelector);
        if ([proxy respondsToSelector:nameSelector]) name = ((id (*)(id, SEL))objc_msgSend)(proxy, nameSelector);

        // Private LaunchServices versions differ: icon selectors may return UIImage or encoded NSData.
        for (NSInteger variant = 2; variant >= 0 && !icon; variant--) {
            id iconResult = nil;
            if ([proxy respondsToSelector:iconSelector]) {
                iconResult = ((id (*)(id, SEL, NSInteger))objc_msgSend)(proxy, iconSelector, variant);
            }
            if ((!iconResult || iconResult == [NSNull null]) && [proxy respondsToSelector:iconOptionsSelector]) {
                iconResult = ((id (*)(id, SEL, NSInteger, NSDictionary *))objc_msgSend)(proxy, iconOptionsSelector, variant, @{});
            }
            if ([iconResult isKindOfClass:[UIImage class]]) {
                icon = iconResult;
            } else if ([iconResult isKindOfClass:[NSData class]] && [iconResult length] > 0) {
                icon = [UIImage imageWithData:iconResult];
            } else if ([iconResult isKindOfClass:[NSDictionary class]]) {
                id nestedData = iconResult[@"data"] ?: iconResult[@"imageData"];
                if ([nestedData isKindOfClass:[NSData class]]) icon = [UIImage imageWithData:nestedData];
                else if ([nestedData isKindOfClass:[UIImage class]]) icon = nestedData;
            }
        }
        // UIKit fallback: LaunchServices iconDataForVariant: may return nil on some iOS 15 builds.
        if (!icon && bundleID.length) {
            SEL imageSelector = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
            if ([UIImage respondsToSelector:imageSelector]) {
                icon = ((id (*)(id, SEL, id, NSInteger, CGFloat))objc_msgSend)(
                    [UIImage class], imageSelector, bundleID, 0, [UIScreen mainScreen].scale
                );
            }
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
    cell.imageView.image = nil;
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
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

@interface FLUAppListsController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<NSDictionary *> *allApps;
@property (nonatomic, copy) NSArray<NSDictionary *> *visibleApps;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UISegmentedControl *modeControl;
@end

@implementation FLUAppListsController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Чёрный и белый списки";
    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"Все", @"Чёрный", @"Белый"]];
    self.modeControl.frame = CGRectMake(16, 8, self.view.bounds.size.width - 32, 32);
    self.modeControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.modeControl addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 48)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:self.modeControl];
    self.tableView.tableHeaderView = header;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Поиск приложения";
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
    [self reloadApps];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshMode];
    [self reloadApps];
}
- (NSDictionary *)settings {
    return FLUReadSettings();
}
- (void)refreshMode {
    NSString *mode = [self settings][@"ListMode"];
    if ([mode isEqualToString:@"blacklist"]) self.modeControl.selectedSegmentIndex = 1;
    else if ([mode isEqualToString:@"whitelist"]) self.modeControl.selectedSegmentIndex = 2;
    else self.modeControl.selectedSegmentIndex = 0;
}
- (void)modeChanged {
    NSArray *modes = @[@"all", @"blacklist", @"whitelist"];
    NSInteger idx = self.modeControl.selectedSegmentIndex;
    if (idx < 0 || idx >= (NSInteger)modes.count) idx = 0;
    NSMutableDictionary *settings = [FLUReadSettings() mutableCopy];
    settings[@"ListMode"] = modes[idx];
    if ([settings writeToFile:FLUPreferencesPath atomically:YES]) FLUPostReload();
    [self.tableView reloadData];
}
- (void)reloadApps {
    self.allApps = FLUInstalledApps();
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
- (NSSet<NSString *> *)membersForCurrentList {
    NSString *key = self.modeControl.selectedSegmentIndex == 1 ? @"Blacklist" : @"Whitelist";
    id raw = [self settings][key];
    return [raw isKindOfClass:[NSArray class]] ? [NSSet setWithArray:raw] : [NSSet set];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visibleApps.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AppListCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AppListCell"];
    NSDictionary *app = self.visibleApps[indexPath.row];
    cell.textLabel.text = app[@"name"];
    cell.detailTextLabel.text = app[@"id"];
    cell.imageView.image = [app[@"icon"] isKindOfClass:[UIImage class]] ? app[@"icon"] : nil;
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    cell.imageView.layer.cornerRadius = 8.0;
    cell.imageView.clipsToBounds = YES;
    if (self.modeControl.selectedSegmentIndex == 0) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryType = [[self membersForCurrentList] containsObject:app[@"id"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.modeControl.selectedSegmentIndex == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Выбери список" message:@"Переключись на «Чёрный» или «Белый», чтобы добавить или убрать приложение." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSDictionary *app = self.visibleApps[indexPath.row];
    NSString *key = self.modeControl.selectedSegmentIndex == 1 ? @"Blacklist" : @"Whitelist";
    NSMutableDictionary *settings = [FLUReadSettings() mutableCopy];
    NSMutableSet<NSString *> *members = [NSMutableSet setWithArray:[settings[key] isKindOfClass:[NSArray class]] ? settings[key] : @[]];
    NSString *bundleID = app[@"id"];
    if ([members containsObject:bundleID]) [members removeObject:bundleID];
    else [members addObject:bundleID];
    settings[key] = [[members allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if ([settings writeToFile:FLUPreferencesPath atomically:YES]) FLUPostReload();
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
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
- (void)manageAppLists:(PSSpecifier *)specifier {
    [self.navigationController pushViewController:[[FLUAppListsController alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES];
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
