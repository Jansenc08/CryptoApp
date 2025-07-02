//
//  TabBarController.m
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//
#import "TabBarController.h"
#import "CryptoApp-Swift.h"

@implementation TabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [UITabBar appearance].tintColor = [UIColor systemGreenColor];

    self.viewControllers = @[[self createMarketsNC], [self createSearchNC]];
}

- (UINavigationController *)createMarketsNC {
    CoinListVC *marketsVC = [[CoinListVC alloc] init];
    marketsVC.title = @"Markets";
    marketsVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Markets"
                                                         image:[UIImage systemImageNamed:@"chart.line.uptrend.xyaxis"]
                                                           tag:0];
    
    return [[UINavigationController alloc] initWithRootViewController:marketsVC];
}

- (UINavigationController *)createSearchNC {
    UIViewController *searchPlaceholderVC = [[UIViewController alloc] init];
    searchPlaceholderVC.view.backgroundColor = [UIColor systemBackgroundColor];
    searchPlaceholderVC.title = @"Search";
    searchPlaceholderVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Search"
                                                                   image:[UIImage systemImageNamed:@"magnifyingglass"]
                                                                     tag:1];
    
    return [[UINavigationController alloc] initWithRootViewController:searchPlaceholderVC];
}

@end

