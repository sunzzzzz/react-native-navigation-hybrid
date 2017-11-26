//
//  HBDViewController.m
//  Pods
//
//  Created by Listen on 2017/11/25.
//

#import "HBDViewController.h"

@interface HBDViewController ()

@end

@implementation HBDViewController

- (instancetype)initWithNavigator:(HBDNavigator *)navigator; {
    if (self = [super init]) {
        _navigator = navigator;
        _sceneId = [[NSUUID UUID] UUIDString];
    }
    return self;
}

- (void)didReceiveResultCode:(NSInteger)resultCode resultData:(NSDictionary *)data requestCode:(NSInteger)requestCode {
    NSLog(@"requestCode:%d, resultCode:%d, data:%@", requestCode, resultCode, data);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end