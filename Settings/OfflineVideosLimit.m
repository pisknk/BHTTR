//
//  OfflineVideosLimit.m
//  StaticTableView
//

#import "OfflineVideosLimit.h"

@interface OfflineVideosLimit () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSArray *limitTitles;
@property (nonatomic, strong) NSArray *limitValues;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation OfflineVideosLimit

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Offline Videos Limit";
    // 0 = Default (stock behavior); the rest override TikTok's offline video count
    self.limitTitles = @[@"Default", @"50 videos", @"100 videos", @"200 videos", @"500 videos", @"1000 videos"];
    self.limitValues = @[@0, @50, @100, @200, @500, @1000];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.limitValues.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    cell.textLabel.text = self.limitTitles[indexPath.row];

    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSNumber *selectedLimit = self.limitValues[indexPath.row];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:selectedLimit forKey:@"offline_videos_limit"];
    [defaults synchronize];

    NSString *message = [NSString stringWithFormat:@"You selected: %@", self.limitTitles[indexPath.row]];
    if ([selectedLimit integerValue] >= 500) {
        message = [message stringByAppendingString:@"\nDownloads refill gradually and need enough free storage."];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Offline Videos Limit" message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RegionSelectedNotification"
                                                        object:nil
                                                      userInfo:@{@"selected limit": selectedLimit}];
}

@end
