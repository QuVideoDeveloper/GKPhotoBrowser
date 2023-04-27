//
//  GKPhotoManager.m
//  GKPhotoBrowserDemo
//
//  Created by gaokun on 2020/6/16.
//  Copyright © 2020 QuintGao. All rights reserved.
//

#import "GKPhotoManager.h"

@interface GKPhoto()

@property (nonatomic, assign) PHImageRequestID imageRequestID;
@property (nonatomic, assign) PHImageRequestID videoRequestID;

@end

@implementation GKPhoto

- (BOOL)isVideo {
    return self.videoUrl || self.videoAsset;
}

- (void)getImageWithOrigin:(BOOL)origin completion:(void (^)(NSData * _Nullable, UIImage * _Nullable))completion progress:(void (^)(double, NSString *))progress {
    if (!self.imageAsset) {
        completion(nil, nil);
        return;
    }
    __weak __typeof(self) weakSelf = self;
    if (self.imageRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:self.imageRequestID];
        self.imageRequestID = 0;
    }
    
    PHAsset *phAsset = self.imageAsset;
    if (phAsset.mediaType == PHAssetMediaTypeImage) {
        // Gif
        if ([[phAsset valueForKey:@"filename"] hasSuffix:@"GIF"]) {
            self.imageRequestID = [GKPhotoManager loadImageDataWithImageAsset:phAsset completion:^(NSData * _Nullable data) {
                __strong __typeof(weakSelf) self = weakSelf;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (data) {
                        !completion ?: completion(data, nil);
                        self.imageRequestID = 0;
                    }
                });
            }];
        }else {
            self.imageRequestID = [GKPhotoManager loadImageWithAsset:phAsset origin: origin photoWidth:GKScreenW * 2 completion:^(UIImage * _Nullable image) {
                __strong __typeof(weakSelf) self = weakSelf;
                dispatch_async(dispatch_get_main_queue(), ^{
                    !completion ?: completion(nil, image);
                    self.imageRequestID = 0;
                });
            } progress:^(double pro, NSString * _Nonnull ident) {
                NSLog(@"<progress> GKPhoto photo: %p, progress: %lf, identifier: %@", self, pro, ident);
                progress(pro, ident);
            }];
        }
    }
}

- (void)getVideo:(void (^)(NSURL * _Nullable))completion {
    if (!self.isVideo) {
        completion(nil);
        return;
    }
    __weak __typeof(self) weakSelf = self;
    if (self.videoRequestID) {
        [[PHImageManager defaultManager] cancelImageRequest:self.videoRequestID];
        self.videoRequestID = 0;
    }
    PHAsset *asset = self.videoAsset;
    if (asset && asset.mediaType == PHAssetMediaTypeVideo) {
        self.videoRequestID = [GKPhotoManager loadVideoWithAsset:asset completion:^(NSURL * _Nonnull url) {
            __strong __typeof(weakSelf) self = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.videoUrl = url;
                self.videoRequestID = 0;
                !completion ?: completion(url);
            });
        }];
    }else {
        !completion ?: completion(self.videoUrl);
    }
}

@end

@implementation GKPhotoManager

+ (PHImageRequestID)loadImageDataWithImageAsset:(PHAsset *)imageAsset completion:(void (^)(NSData * _Nullable))completion {
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.networkAccessAllowed = YES;
    options.resizeMode = PHImageRequestOptionsResizeModeFast;
    PHImageRequestID requestID = [[PHImageManager defaultManager] requestImageDataForAsset:imageAsset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        BOOL complete = ![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey] && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue];
        if (complete && imageData) {
            completion(imageData);
        } else {
            completion(nil);
        }
    }];
    return requestID;
}

+ (PHImageRequestID)loadImageWithAsset:(PHAsset *)asset origin:(BOOL)origin photoWidth:(CGFloat)photoWidth completion:(void (^)(UIImage * _Nullable))completion progress:(void (^)(double, NSString *))progress {
    CGSize imageSize;
    CGFloat scale = 2.0;
    if (UIScreen.mainScreen.bounds.size.width > 700) {
        scale = 1.5;
    }
    CGFloat aspectRatio = asset.pixelWidth / (CGFloat)asset.pixelHeight;
    CGFloat pixelWidth = photoWidth * scale;
    if (origin) {
        pixelWidth = asset.pixelWidth;
    }
    // 超宽图片
    if (aspectRatio > 1.8) {
        pixelWidth = pixelWidth * aspectRatio;
    }
    // 超高图片
    if (aspectRatio < 0.2) {
        pixelWidth = pixelWidth * 0.5;
    }
    CGFloat pixelHeight = pixelWidth / aspectRatio;
    imageSize = CGSizeMake(pixelWidth, pixelHeight);
    
    PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
    option.networkAccessAllowed = YES;
    option.resizeMode = PHImageRequestOptionsResizeModeFast;
    if (origin) {
        option.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    }
    
    NSString * identifier = asset.localIdentifier;
    option.progressHandler = ^(double progressValue, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
        NSLog(@"<progress> download iCloud下载进度 %lf, identifier: %@", progressValue, identifier);
        if (progress) {
            progress(progressValue, identifier);
        }
    };
    
    // 直接使用原图
    PHImageRequestID requestID = [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:imageSize contentMode:PHImageContentModeAspectFill options:option resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        BOOL cancelled = [[info objectForKey:PHImageCancelledKey] boolValue];
        if (!cancelled && result) {
            !completion ? : completion(result);
        }
    }];
    return requestID;
}

+ (PHImageRequestID)loadVideoWithAsset:(PHAsset *)asset completion:(void (^)(NSURL * _Nonnull))completion {
    PHVideoRequestOptions *option = [[PHVideoRequestOptions alloc] init];
    option.networkAccessAllowed = YES;
    option.progressHandler = nil;
    PHImageRequestID requestID = [[PHImageManager defaultManager] requestPlayerItemForVideo:asset options:option resultHandler:^(AVPlayerItem *playerItem, NSDictionary *info) {
        AVURLAsset *urlAsset = (AVURLAsset *)playerItem.asset;
        !completion ?: completion(urlAsset.URL);
    }];
    return requestID;
}

@end
