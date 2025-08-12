//
//  CoinImageView.m
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//

#import "CoinImageView.h"
#import "CryptoApp-Swift.h" // For accessing Swift ImageLoader

@interface CoinImageView ()
@property (nonatomic, strong) NSString *currentDownloadURL;
@end

@implementation CoinImageView

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentMode = UIViewContentModeScaleAspectFit;
    self.clipsToBounds = YES;
    [self setPlaceholder];
    // No longer need per-instance cache - using shared ImageCacheService
}

- (void)setPlaceholder {
    [self cancelCurrentDownload];
    self.image = [UIImage imageNamed:@"coin_placeholder"];
}

- (void)cancelCurrentDownload {
    // Cancel any in-flight load for the previous URL
    if (self.currentDownloadURL && self.currentDownloadURL.length > 0) {
        [[ImageLoader shared] cancelLoadFor:self.currentDownloadURL];
    }
    self.currentDownloadURL = nil;
}

- (void)downloadImageFromURL:(NSString *)urlString {
    if (!urlString || urlString.length == 0) {
        [self setPlaceholder];
        return;
    }

    // Cancel any existing download first
    [self cancelCurrentDownload];
    
    // Store the current download URL for race condition prevention
    self.currentDownloadURL = urlString;

    // Use the optimized ImageLoader that integrates with existing CacheService
    __weak typeof(self) weakSelf = self;
    [[ImageLoader shared] loadImageFrom:urlString completion:^(UIImage * _Nullable image) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // RACE CONDITION FIX: Only apply image if this is still the current download
        if (![strongSelf.currentDownloadURL isEqualToString:urlString]) {
            return;
        }
        
        if (image) {
            strongSelf.image = image;
            strongSelf.currentDownloadURL = nil;
        } else {
            [strongSelf setPlaceholder];
        }
    }];
}
@end
