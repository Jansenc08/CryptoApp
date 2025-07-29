//
//  CoinImageView.h
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//

#import <UIKit/UIKit.h>

@interface CoinImageView : UIImageView

- (void)setPlaceholder;
- (void)downloadImageFromURL:(NSString *)urlString;
- (void)cancelCurrentDownload;

@end

