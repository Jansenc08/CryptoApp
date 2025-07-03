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
        [self setPlaceholder];
        return;
    }

    NSString *cacheKey = urlString;
    UIImage *cachedImage = [self.imageCache objectForKey:cacheKey];

    if (cachedImage) {
        self.image = cachedImage;
        return;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        [self setPlaceholder];
        return;
    }

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:url
      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
          if (error || !data) {
              dispatch_async(dispatch_get_main_queue(), ^{
                  [self setPlaceholder];
              });
              return;
          }

          UIImage *downloadedImage = [UIImage imageWithData:data];
          if (downloadedImage) {
              [self.imageCache setObject:downloadedImage forKey:cacheKey];
              dispatch_async(dispatch_get_main_queue(), ^{
                  self.image = downloadedImage;
              });
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                  [self setPlaceholder];
              });
          }
      }];

    [task resume];
}
@end
