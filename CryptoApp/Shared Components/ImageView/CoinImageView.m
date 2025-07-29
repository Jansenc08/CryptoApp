//
//  CoinImageView.m
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//

#import "CoinImageView.h"

@interface CoinImageView ()
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSURLSessionDataTask *currentDownloadTask;
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
    self.imageCache = [[NSCache alloc] init]; // Per-instance cache
}

- (void)setPlaceholder {
    [self cancelCurrentDownload];
    self.image = [UIImage imageNamed:@"coin_placeholder"];
}

- (void)cancelCurrentDownload {
    if (self.currentDownloadTask) {
        [self.currentDownloadTask cancel];
        self.currentDownloadTask = nil;
    }
    self.currentDownloadURL = nil;
}

- (void)downloadImageFromURL:(NSString *)urlString {
    if (!urlString) {
        NSLog(@"❌ CoinImageView | No URL provided, setting placeholder");
        [self setPlaceholder];
        return;
    }

    // Cancel any existing download first
    [self cancelCurrentDownload];
    
    // Store the current download URL for race condition prevention
    self.currentDownloadURL = urlString;

    NSString *cacheKey = urlString;
    UIImage *cachedImage = [self.imageCache objectForKey:cacheKey];

    if (cachedImage) {
        NSLog(@"💾 CoinImageView | Cache hit for: %@", urlString);
        self.image = cachedImage;
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSLog(@"❌ CoinImageView | Invalid URL: %@", urlString);
        [self setPlaceholder];
        return;
    }

    // Only log download start for debugging if needed
    // NSLog(@"🌐 CoinImageView | Downloading image from: %@", urlString);

    __weak typeof(self) weakSelf = self;
    self.currentDownloadTask = [[NSURLSession sharedSession]
        dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
          __strong typeof(weakSelf) strongSelf = weakSelf;
          if (!strongSelf) return;
          
          // RACE CONDITION FIX: Only apply image if this is still the current download
          if (![strongSelf.currentDownloadURL isEqualToString:urlString]) {
              NSLog(@"🛑 CoinImageView | Ignoring download result for %@ (no longer current)", urlString);
              return;
          }
          
          if (error) {
              NSLog(@"❌ CoinImageView | Download error for %@: %@", urlString, error.localizedDescription);
              dispatch_async(dispatch_get_main_queue(), ^{
                  // Only set placeholder if this is still the current download
                  if ([strongSelf.currentDownloadURL isEqualToString:urlString]) {
                      [strongSelf setPlaceholder];
                  }
              });
              return;
          }
          
          if (!data) {
              NSLog(@"❌ CoinImageView | No data received for: %@", urlString);
              dispatch_async(dispatch_get_main_queue(), ^{
                  // Only set placeholder if this is still the current download
                  if ([strongSelf.currentDownloadURL isEqualToString:urlString]) {
                      [strongSelf setPlaceholder];
                  }
              });
              return;
          }

          UIImage *downloadedImage = [UIImage imageWithData:data];
          if (downloadedImage) {
              // Only log success for debugging if needed
              // NSLog(@"✅ CoinImageView | Successfully downloaded image for: %@", urlString);
              [strongSelf.imageCache setObject:downloadedImage forKey:cacheKey];
              dispatch_async(dispatch_get_main_queue(), ^{
                  // RACE CONDITION FIX: Only apply image if this is still the current download
                  if ([strongSelf.currentDownloadURL isEqualToString:urlString]) {
                      strongSelf.image = downloadedImage;
                      strongSelf.currentDownloadTask = nil;
                      strongSelf.currentDownloadURL = nil;
                  }
              });
          } else {
              NSLog(@"❌ CoinImageView | Failed to create image from data for: %@", urlString);
              dispatch_async(dispatch_get_main_queue(), ^{
                  // Only set placeholder if this is still the current download
                  if ([strongSelf.currentDownloadURL isEqualToString:urlString]) {
                      [strongSelf setPlaceholder];
                  }
              });
          }
      }];

    [self.currentDownloadTask resume];
}
@end
