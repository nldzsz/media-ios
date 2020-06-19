//
//  VideoFileSource.h
//  media
//
//  Created by 飞拍科技 on 2019/6/10.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GLDefine.h"
#import <CoreMedia/CoreMedia.h>

@protocol VideoFileSourceProtocol <NSObject>

- (void)pushYUVFrame:(VideoFrame*)video;

// 视频流没有了
- (void)didFinishVideoData;
@end

@interface VideoFileSource : NSObject
@property (assign, nonatomic) id<VideoFileSourceProtocol>delegate;
@property (strong, nonatomic) NSURL *fURL;
@property (strong, nonatomic) NSThread  *workThread;
@property (assign, nonatomic) BOOL isPull;
@property (assign, nonatomic) int width;
@property (assign, nonatomic) int height;

- (id)initWithFileUrl:(NSURL*)fileUrl;
// 设置yuv中的视频宽和高 很重要
- (void)setVideoWidth:(int)width height:(int)height;

- (void)beginPullVideo;
- (void)stop;
@end
