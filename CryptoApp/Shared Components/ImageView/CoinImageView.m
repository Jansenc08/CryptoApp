//
//  CoinImageView.m
//  CryptoApp
//
//  Created by Jansen Castillo on 1/7/25.
//

#import "CoinImageView.h"

@interface CoinImageView ()
@property (nonatomic, strong) NSCache *imageCache;
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
    self.image = [UIImage imageNamed:@"coin_placeholder"];
}

- (void)downloadImageFromURL:(NSString *)urlString {
    if (!urlString) {
        NSLog(@"❌ CoinImageView | No URL provided, setting placeholder");
        [self setPlaceholder];
        return;
    }

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

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:url
      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
          if (error) {
              NSLog(@"❌ CoinImageView | Download error for %@: %@", urlString, error.localizedDescription);
              dispatch_async(dispatch_get_main_queue(), ^{
                  [self setPlaceholder];
              });
              return;
          }
          
          if (!data) {
              NSLog(@"❌ CoinImageView | No data received for: %@", urlString);
              dispatch_async(dispatch_get_main_queue(), ^{
                  [self setPlaceholder];
              });
              return;
          }

          UIImage *downloadedImage = [UIImage imageWithData:data];
          if (downloadedImage) {
              // Only log success for debugging if needed
              // NSLog(@"✅ CoinImageView | Successfully downloaded image for: %@", urlString);
              [self.imageCache setObject:downloadedImage forKey:cacheKey];
              dispatch_async(dispatch_get_main_queue(), ^{
                  self.image = downloadedImage;
              });
          } else {
              NSLog(@"❌ CoinImageView | Failed to create image from data for: %@", urlString);
              dispatch_async(dispatch_get_main_queue(), ^{
                  [self setPlaceholder];
              });
          }
      }];

    [task resume];
}
@end
