//
//  LabsViewController.m
//  StaticTableView
//
//  Labs: A/B experiment explorer. Catalog is read from TikTok's own Libra/ABTest
//  stores (AWEABTestManager.stableValues / currentActiveABTestData / readABTestData,
//  AWEABTestObjCDataStore.getAllConfig, AWEABTestInfoManager.allABTestPropertyList —
//  all verified in MusicallyCore 46.5.0 ObjC metadata). Overrides persist in
//  NSUserDefaults "ab_overrides" and are applied via TikTok's own debug-override
//  mock layer (+ hooks in Tweak.x).
//

#import "LabsViewController.h"
#import "../BHIManager.h"
#import <objc/message.h>

@interface LabsViewController () <UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) NSMutableDictionary *catalog;   // key -> original value (id)
@property (nonatomic, strong) NSArray *allKeys;
@property (nonatomic, strong) NSArray *filteredKeys;
@property (nonatomic, strong) NSMutableDictionary *overrides; // key -> override value (id)
@end

@implementation LabsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Labs — A/B Explorer";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = self.searchController;

    [self reloadOverrides];
    [self loadCatalog];
    self.tableView.tableFooterView = [self buildFooter];
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadOverrides];
    [self.tableView reloadData];
}

#pragma mark - helpers

- (id)callNoArg:(id)target selector:(SEL)sel {
    if (target == nil || ![target respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(target, sel);
}

- (BOOL)isBoolNumber:(id)value {
    // CFBoolean identity check — @encode(BOOL) is "B" on arm64 while boxed bools report "c",
    // so an encoding compare would misfire; CFBooleanGetTypeID covers both.
    return [value isKindOfClass:[NSNumber class]] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

- (NSString *)typeBadge:(id)value {
    if ([self isBoolNumber:value]) return @"bool";
    if ([value isKindOfClass:[NSNumber class]]) return @"number";
    if ([value isKindOfClass:[NSString class]]) return @"string";
    if ([value isKindOfClass:[NSDictionary class]]) return @"dict";
    if ([value isKindOfClass:[NSArray class]]) return @"array";
    return NSStringFromClass([value class]);
}

- (NSString *)valueDescription:(id)value {
    NSString *desc = [value description] ?: @"?";
    if (desc.length > 80) desc = [[desc substringToIndex:80] stringByAppendingString:@"…"];
    return desc;
}

- (id)jsonSafe:(id)obj {
    if (obj == nil) return [NSNull null];
    if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) return obj;
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary new];
        [(NSDictionary *)obj enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) {
            d[[k description]] = [self jsonSafe:v];
        }];
        return d;
    }
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray new];
        for (id v in (NSArray *)obj) [a addObject:[self jsonSafe:v]];
        return a;
    }
    return [obj description];
}

#pragma mark - catalog loading

- (void)mergeValue:(id)value {
    if (![value isKindOfClass:[NSDictionary class]]) return;
    [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (![key isKindOfClass:[NSString class]]) return;
        if (self.catalog[key] == nil) {
            id v = obj;
            if ([v isKindOfClass:[NSDictionary class]] && ((NSDictionary *)v)[@"value"] != nil) {
                v = ((NSDictionary *)v)[@"value"]; // common {..., value: X} wrapper shape
            }
            self.catalog[key] = v;
        }
    }];
}

- (void)loadCatalog {
    self.catalog = [NSMutableDictionary new];
    @try {
        id mgr = [self callNoArg:NSClassFromString(@"AWEABTestManager") selector:@selector(sharedManager)];
        for (NSString *name in @[@"stableValues", @"currentActiveABTestData", @"readABTestData"]) {
            [self mergeValue:[self callNoArg:mgr selector:NSSelectorFromString(name)]];
        }
        id objStore = [self callNoArg:NSClassFromString(@"AWEABTestObjCDataStore") selector:NSSelectorFromString(@"shared")];
        [self mergeValue:[self callNoArg:objStore selector:NSSelectorFromString(@"getAllConfig")]];
        id dataStore = [self callNoArg:NSClassFromString(@"AWEABTestDataStore") selector:NSSelectorFromString(@"shared")];
        [self mergeValue:[self callNoArg:dataStore selector:NSSelectorFromString(@"getAllConfig")]];
        // registered-but-uncached flags (names only, from TikTok's own registry)
        id propList = [self callNoArg:NSClassFromString(@"AWEABTestInfoManager") selector:NSSelectorFromString(@"allABTestPropertyList")];
        if ([propList isKindOfClass:[NSArray class]]) {
            for (id item in (NSArray *)propList) {
                if ([item isKindOfClass:[NSString class]] && self.catalog[item] == nil) {
                    self.catalog[item] = @"(registered, no cached value)";
                }
            }
        }
    } @catch (NSException *ex) {
        NSLog(@"[BHTTR Labs] catalog load failed: %@", ex);
    }
    self.allKeys = [[self.catalog allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    self.filteredKeys = self.allKeys;
}

#pragma mark - overrides persistence + TikTok mock layer

- (void)reloadOverrides {
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"ab_overrides"];
    self.overrides = saved ? [saved mutableCopy] : [NSMutableDictionary new];
}

- (void)persistOverrides {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (self.overrides.count > 0) {
        [defaults setObject:self.overrides forKey:@"ab_overrides"];
    } else {
        [defaults removeObjectForKey:@"ab_overrides"];
    }
    [defaults synchronize];
}

// Apply overrides through TikTok's own debug-override mock layer (verified present in 46.5.0)
- (void)applyOverridesToMock {
    Class mgr = NSClassFromString(@"AWEABTestManager");
    if (mgr == nil) return;
    [self callNoArg:mgr selector:NSSelectorFromString(@"debugOverride_ClearAllMock")];
    SEL enableSel = NSSelectorFromString(@"debugOverride_EnabledMock:");
    if ([mgr respondsToSelector:enableSel]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(mgr, enableSel, self.overrides.count > 0);
    }
    SEL setSel = NSSelectorFromString(@"debugOverride_SetMockValue:forKey:");
    if ([mgr respondsToSelector:setSel]) {
        for (NSString *key in self.overrides) {
            ((void (*)(id, SEL, id, id))objc_msgSend)(mgr, setSel, self.overrides[key], key);
        }
    }
}

#pragma mark - footer (notice + actions)

- (UIView *)buildFooter {
    CGFloat width = UIScreen.mainScreen.bounds.size.width;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 190)];

    UILabel *notice = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, width - 30, 36)];
    notice.text = @"Overrides apply to cached flags on next read — restart TikTok for full effect.";
    notice.font = [UIFont systemFontOfSize:13];
    notice.textColor = [UIColor systemOrangeColor];
    notice.numberOfLines = 0;
    [footer addSubview:notice];

    UILabel *warning = [[UILabel alloc] initWithFrame:CGRectMake(15, 48, width - 30, 50)];
    warning.text = @"Some flags are server-side only and won't respond. Avoid payment/commerce flags (PIPO*, EC*). You are responsible for what you change.";
    warning.font = [UIFont systemFontOfSize:12];
    warning.textColor = [UIColor grayColor];
    warning.numberOfLines = 0;
    [footer addSubview:warning];

    UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    resetButton.frame = CGRectMake(15, 104, width - 30, 32);
    [resetButton setTitle:@"Reset All Overrides" forState:UIControlStateNormal];
    [resetButton addTarget:self action:@selector(resetTapped) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:resetButton];

    UIButton *dumpButton = [UIButton buttonWithType:UIButtonTypeSystem];
    dumpButton.frame = CGRectMake(15, 140, width - 30, 32);
    [dumpButton setTitle:@"Dump Catalog (JSON)" forState:UIControlStateNormal];
    [dumpButton addTarget:self action:@selector(dumpTapped) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:dumpButton];

    return footer;
}

- (void)resetTapped {
    [self.overrides removeAllObjects];
    [self persistOverrides];
    [self applyOverridesToMock];
    [self.tableView reloadData];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Overrides Cleared"
        message:@"Restart TikTok for stock values to fully return." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dumpTapped {
    @try {
        NSMutableDictionary *dump = [NSMutableDictionary new];
        dump[@"catalog_merged"] = [self jsonSafe:self.catalog];
        dump[@"ab_overrides"] = [self jsonSafe:self.overrides];
        NSDictionary *ud = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
        NSMutableDictionary *abUd = [NSMutableDictionary new];
        [ud enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) {
            NSString *low = [[k description] lowercaseString];
            if ([low containsString:@"ab"] || [low containsString:@"libra"] || [low containsString:@"experiment"]) {
                abUd[[k description]] = [self jsonSafe:v];
            }
        }];
        dump[@"userdefaults_ab_like"] = abUd;
        id mgr = [self callNoArg:NSClassFromString(@"AWEABTestManager") selector:@selector(sharedManager)];
        for (NSString *name in @[@"stableValues", @"currentActiveABTestData", @"readABTestData", @"_retriveABTestData", @"consistentABTestDic", @"unstableABTestDic"]) {
            id v = [self callNoArg:mgr selector:NSSelectorFromString(name)];
            if (v) dump[[@"raw_" stringByAppendingString:name]] = [self jsonSafe:v];
        }
        id objStore = [self callNoArg:NSClassFromString(@"AWEABTestObjCDataStore") selector:NSSelectorFromString(@"shared")];
        id cfg = [self callNoArg:objStore selector:NSSelectorFromString(@"getAllConfig")];
        if (cfg) dump[@"raw_objcDataStore_getAllConfig"] = [self jsonSafe:cfg];
        NSData *json = [NSJSONSerialization dataWithJSONObject:dump options:NSJSONWritingPrettyPrinted error:nil];
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"bhttr_labs_dump.json"];
        [json writeToFile:path atomically:YES];
        [BHIManager showSaveVC:[NSURL fileURLWithPath:path]];
    } @catch (NSException *ex) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dump Failed"
            message:[ex description] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - UITableView

- (BOOL)isFiltering {
    return self.searchController.active && self.searchController.searchBar.text.length > 0;
}

- (NSArray *)visibleKeys {
    return [self isFiltering] ? self.filteredKeys : self.allKeys;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self visibleKeys].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"LabsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    NSString *key = [self visibleKeys][indexPath.row];
    id overrideValue = self.overrides[key];
    id effective = overrideValue ?: self.catalog[key];
    cell.textLabel.text = key;
    cell.textLabel.textColor = overrideValue ? [UIColor systemOrangeColor] : [UIColor labelColor];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  ·  %@%@", [self valueDescription:effective], [self typeBadge:effective], overrideValue ? @"  ·  overridden" : @""];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *key = [self visibleKeys][indexPath.row];
    id original = self.catalog[key];
    id overrideValue = self.overrides[key];
    id effective = overrideValue ?: original;
    BOOL hasOverride = overrideValue != nil;

    if ([self isBoolNumber:effective]) {
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:key
            message:[NSString stringWithFormat:@"Current: %@ (%@)", [effective boolValue] ? @"true" : @"false", hasOverride ? @"override" : @"stock"]
            preferredStyle:UIAlertControllerStyleActionSheet];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Set true" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self saveOverride:@YES forKey:key];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Set false" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self saveOverride:@NO forKey:key];
        }]];
        if (hasOverride) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"Remove Override" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
                [self removeOverrideForKey:key];
            }]];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:sheet animated:YES completion:nil];
        return;
    }

    if ([effective isKindOfClass:[NSNumber class]] || [effective isKindOfClass:[NSString class]]) {
        BOOL isNumber = [effective isKindOfClass:[NSNumber class]];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:key
            message:[NSString stringWithFormat:@"Type: %@ · Current: %@", [self typeBadge:effective], [self valueDescription:effective]]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.text = [effective description];
            textField.keyboardType = isNumber ? UIKeyboardTypeNumbersAndPunctuation : UIKeyboardTypeDefault;
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Save Override" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            NSString *input = alert.textFields.firstObject.text;
            id newValue = nil;
            if (isNumber) {
                NSNumberFormatter *formatter = [NSNumberFormatter new];
                newValue = [formatter numberFromString:input];
                if (newValue == nil) {
                    [self showNotice:@"Invalid Number" detail:@"Value kept unchanged."];
                    return;
                }
                if ([self isBoolNumber:original]) { // never change a bool flag into a plain number
                    newValue = @([newValue boolValue]);
                }
            } else {
                newValue = input;
            }
            [self saveOverride:newValue forKey:key];
        }]];
        if (hasOverride) {
            [alert addAction:[UIAlertAction actionWithTitle:@"Remove Override" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
                [self removeOverrideForKey:key];
            }]];
        }
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // dict/array/unknown — do not allow type-changing edits
    UIAlertController *info = [UIAlertController alertControllerWithTitle:key
        message:[NSString stringWithFormat:@"Value type (%@) is not editable safely.", [self typeBadge:effective]]
        preferredStyle:UIAlertControllerStyleAlert];
    if (hasOverride) {
        [info addAction:[UIAlertAction actionWithTitle:@"Remove Override" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [self removeOverrideForKey:key];
        }]];
    }
    [info addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:info animated:YES completion:nil];
}

- (void)saveOverride:(id)value forKey:(NSString *)key {
    self.overrides[key] = value;
    [self persistOverrides];
    [self applyOverridesToMock];
    [self.tableView reloadData];
    [self showNotice:@"Override Saved" detail:@"Restart TikTok for the change to fully apply."];
}

- (void)removeOverrideForKey:(NSString *)key {
    [self.overrides removeObjectForKey:key];
    [self persistOverrides];
    [self applyOverridesToMock];
    [self.tableView reloadData];
    [self showNotice:@"Override Removed" detail:@"Restart TikTok for the stock value to fully return."];
}

- (void)showNotice:(NSString *)title detail:(NSString *)detail {
    UIAlertController *note = [UIAlertController alertControllerWithTitle:title message:detail
        preferredStyle:UIAlertControllerStyleAlert];
    [note addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:note animated:YES completion:nil];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text.lowercaseString;
    if (query.length == 0) {
        self.filteredKeys = self.allKeys;
    } else {
        self.filteredKeys = [self.allKeys filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"self.lowercaseString CONTAINS %@", query]];
    }
    [self.tableView reloadData];
}

@end
