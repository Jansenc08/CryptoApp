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
    
    [UITabBar appearance].tintColor = [UIColor systemBlueColor];

    self.viewControllers = @[[self createMarketsNC], [self createSearchNC]];
}

- (UINavigationController *)createMarketsNC {
    CoinListVC *marketsVC = [[CoinListVC alloc] init];
    marketsVC.title = @"Markets";
    marketsVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Markets"
                                                         image:[UIImage systemImageNamed:@"chart.line.uptrend.xyaxis"]
                                                           tag:0];
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:marketsVC];
    
    // Enable large titles support globally for this navigation stack (best practice)
    navController.navigationBar.prefersLargeTitles = YES;
    
    return navController;
}

- (UINavigationController *)createSearchNC {
    SearchVC *searchVC = [[SearchVC alloc] init];
    searchVC.title = @"Search";
    searchVC.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Search"
                                                        image:[UIImage systemImageNamed:@"magnifyingglass"]
                                                          tag:1];
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:searchVC];
    
    // Enable large titles support globally for this navigation stack (best practice)
    navController.navigationBar.prefersLargeTitles = YES;
    
    return navController;
}

@end

