//
//  HBDNavigationController.m
//  NavigationHybrid
//
//  Created by Listen on 2017/12/16.
//  Copyright © 2018年 Listen. All rights reserved.
//

#import "HBDNavigationController.h"
#import "HBDViewController.h"
#import "UIViewController+HBD.h"
#import "HBDNavigationBar.h"
#import "HBDReactBridgeManager.h"
#import "HBDUtils.h"
#import "HBDGarden.h"

@interface HBDNavigationController () <UIGestureRecognizerDelegate, UINavigationControllerDelegate>

@property (nonatomic, readonly) HBDNavigationBar *navigationBar;
@property (nonatomic, strong) UIVisualEffectView *fromFakeBar;
@property (nonatomic, strong) UIVisualEffectView *toFakeBar;
@property (nonatomic, strong) UIImageView *fromFakeShadow;
@property (nonatomic, strong) UIImageView *toFakeShadow;

@end

@implementation HBDNavigationController

@dynamic navigationBar;

- (void)dealloc {
    NSLog(@"%s", __FUNCTION__);
}

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    if (self = [super initWithNavigationBarClass:[HBDNavigationBar class] toolbarClass:nil]) {
        if ([rootViewController isKindOfClass:[HBDViewController class]]) {
            HBDViewController *root = (HBDViewController *)rootViewController;
            NSDictionary *tabItem = root.options[@"tabItem"];
            [self configTabItemWithDict:tabItem];
        }
        self.viewControllers = @[ rootViewController ];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.interactivePopGestureRecognizer.delegate = self;
    self.delegate = self;
    [self.navigationBar setTranslucent:YES];
    [self.navigationBar setShadowImage:[UINavigationBar appearance].shadowImage];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (self.viewControllers.count > 1) {
        return self.topViewController.hbd_backInteractive;
    }
    return NO;
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    self.navigationBar.barStyle = viewController.hbd_barStyle;
    self.navigationBar.titleTextAttributes = viewController.hbd_titleTextAttributes;
    id<UIViewControllerTransitionCoordinator> coordinator = self.transitionCoordinator;
    if (coordinator) {
        UIViewController *from = [coordinator viewControllerForKey:UITransitionContextFromViewControllerKey];
        UIViewController *to = [coordinator viewControllerForKey:UITransitionContextToViewControllerKey];
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            BOOL shouldFake = to == viewController && (![from.hbd_barTintColor.description  isEqual:to.hbd_barTintColor.description] || ABS(from.hbd_barAlpha - to.hbd_barAlpha) > 0.1);
            if (shouldFake) {
                self.navigationBar.tintColor = viewController.hbd_tintColor;
                [UIView setAnimationsEnabled:NO];
                self.navigationBar.fakeView.alpha = 0;
                self.navigationBar.shadowImageView.alpha = 0;
                
                // from
                self.fromFakeBar.subviews[1].backgroundColor = from.hbd_barTintColor;
                self.fromFakeBar.alpha = from.hbd_barAlpha == 0 ? 0.01:from.hbd_barAlpha;
                if (from.hbd_barAlpha == 0) {
                    self.fromFakeBar.subviews[1].alpha = 0.01;
                }
                self.fromFakeBar.frame = [self fakeBarFrameForViewController:from];
                [from.view addSubview:self.fromFakeBar];
                self.fromFakeShadow.alpha = from.hbd_barShadowAlpha;
                self.fromFakeShadow.frame = [self fakeShadowFrameWithBarFrame:self.fromFakeBar.frame];
                [from.view addSubview:self.fromFakeShadow];
                // to
                self.toFakeBar.subviews[1].backgroundColor = to.hbd_barTintColor;
                self.toFakeBar.alpha = to.hbd_barAlpha;
                self.toFakeBar.frame = [self fakeBarFrameForViewController:to];
                [to.view addSubview:self.toFakeBar];
                self.toFakeShadow.alpha = to.hbd_barShadowAlpha;
                self.toFakeShadow.frame = [self fakeShadowFrameWithBarFrame:self.toFakeBar.frame];
                [to.view addSubview:self.toFakeShadow];
                
                [UIView setAnimationsEnabled:YES];
            } else {
                [self updateNavigationBarForController:viewController];
            }
        } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            if (context.isCancelled) {
                [self updateNavigationBarForController:from];
            } else {
                // 当 present 时 to 不等于 viewController
                [self updateNavigationBarForController:viewController];
            }
            if (to == viewController) {
                [self clearFake];
            }
        }];
    } else {
        [self updateNavigationBarForController:viewController];
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    [self updateNavigationBarForController:viewController];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *vc = [super popViewControllerAnimated:animated];
    self.navigationBar.barStyle = self.topViewController.hbd_barStyle;
    self.navigationBar.titleTextAttributes = self.topViewController.hbd_titleTextAttributes;
    return vc;
}

- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    NSArray *array = [super popToViewController:viewController animated:animated];
    self.navigationBar.barStyle = self.topViewController.hbd_barStyle;
    self.navigationBar.titleTextAttributes = self.topViewController.hbd_titleTextAttributes;
    return array;
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    NSArray *array = [super popToRootViewControllerAnimated:animated];
    self.navigationBar.barStyle = self.topViewController.hbd_barStyle;
    self.navigationBar.titleTextAttributes = self.topViewController.hbd_titleTextAttributes;
    return array;
}

- (UIVisualEffectView *)fromFakeBar {
    if (!_fromFakeBar) {
        _fromFakeBar = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    }
    return _fromFakeBar;
}

- (UIVisualEffectView *)toFakeBar {
    if (!_toFakeBar) {
        _toFakeBar = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    }
    return _toFakeBar;
}

- (UIImageView *)fromFakeShadow {
    if (!_fromFakeShadow) {
        _fromFakeShadow = [[UIImageView alloc] initWithImage:self.navigationBar.shadowImageView.image];
        _fromFakeShadow.backgroundColor = self.navigationBar.shadowImageView.backgroundColor;
    }
    return _fromFakeShadow;
}

- (UIImageView *)toFakeShadow {
    if (!_toFakeShadow) {
        _toFakeShadow = [[UIImageView alloc] initWithImage:self.navigationBar.shadowImageView.image];
        _toFakeShadow.backgroundColor = self.navigationBar.shadowImageView.backgroundColor;
    }
    return _toFakeShadow;
}

- (void)clearFake {
    [self.fromFakeBar removeFromSuperview];
    [self.toFakeBar removeFromSuperview];
    [self.fromFakeShadow removeFromSuperview];
    [self.toFakeShadow removeFromSuperview];
    _fromFakeBar = nil;
    _toFakeBar = nil;
    _fromFakeShadow = nil;
    _toFakeShadow = nil;
}

- (CGRect)fakeBarFrameForViewController:(UIViewController *)vc {
    CGRect frame = [self.navigationBar.fakeView convertRect:self.navigationBar.fakeView.frame toView:vc.view];
    frame.origin.x = vc.view.frame.origin.x;
    return frame;
}

- (CGRect)fakeShadowFrameWithBarFrame:(CGRect)frame {
    return CGRectMake(frame.origin.x, frame.size.height + frame.origin.y, frame.size.width, 0.5);
}

- (void)updateNavigationBarForController:(UIViewController *)vc {
   
    [self updateNavigationBarAlphaForViewController:vc];
    [self updateNavigationBarColorForViewController:vc];
    [self updateNavigationBarShadowImageAlphaForViewController:vc];
    self.navigationBar.barStyle = vc.hbd_barStyle;
    self.navigationBar.tintColor = vc.hbd_tintColor;
    self.navigationBar.titleTextAttributes = vc.hbd_titleTextAttributes;
}

- (void)updateNavigationBarAlphaForViewController:(UIViewController *)vc {
    self.navigationBar.fakeView.alpha = vc.hbd_barAlpha;
    self.navigationBar.shadowImageView.alpha = vc.hbd_barShadowAlpha;
}

- (void)updateNavigationBarColorForViewController:(UIViewController *)vc {
    self.navigationBar.barTintColor = vc.hbd_barTintColor;
}

- (void)updateNavigationBarShadowImageAlphaForViewController:(UIViewController *)vc {
    self.navigationBar.shadowImageView.alpha = vc.hbd_barShadowAlpha;
}

- (void)configTabItemWithDict:(NSDictionary *)tabItem {
    if (tabItem) {
        UITabBarItem *tabBarItem = [[UITabBarItem alloc] init];
        tabBarItem.title = tabItem[@"title"];
        
        NSDictionary *inactiveIcon = tabItem[@"inactiveIcon"];
        if (inactiveIcon) {
            tabBarItem.selectedImage = [[HBDUtils UIImage:tabItem[@"icon"]] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            tabBarItem.image = [[HBDUtils UIImage:inactiveIcon] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        } else {
            tabBarItem.image = [HBDUtils UIImage:tabItem[@"icon"]];
        }
        
        self.tabBarItem = tabBarItem;
        self.hidesBottomBarWhenPushed = [tabItem[@"hideTabBarWhenPush"] boolValue];
    }
}

@end
