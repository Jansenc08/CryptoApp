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
    SearchVC *searchVC = [[SearchVC alloc] init];
    searchVC.title = @"Search";
    searchVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Search"
                                                        image:[UIImage systemImageNamed:@"magnifyingglass"]
                                                          tag:1];
    
    return [[UINavigationController alloc] initWithRootViewController:searchVC];
}

@end

