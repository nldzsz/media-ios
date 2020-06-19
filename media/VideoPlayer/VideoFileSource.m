//
//  VideoFileSource.m
//  media
//
//  Created by 飞拍科技 on 2019/6/10.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "VideoFileSource.h"


@implementation VideoFileSource

- (id)initWithFileUrl:(NSURL *)fileUrl
{
    if (self = [super init]) {
        self.fURL = fileUrl;
        self.isPull = NO;
    }
    
    return self;
}

- (void)setVideoWidth:(int)vwidth height:(int)vheight
{
    self.width = vwidth;
    self.height = vheight;
}

- (void)beginPullVideo
{
    if (self.workThread == nil) {
        self.workThread = [[NSThread alloc] initWithTarget:self selector:@selector(pullRunloop) object:nil];
        [self.workThread start];
    }
}

- (void)pullRunloop
{
    NSString *path = self.fURL.path;
    if (path.length == 0) {
        NSLog(@"路径不能为空");
        return;
    }
    
    // 以二进制方式读取文件
    FILE *yuvFile = fopen([path UTF8String], "rb");
    if (yuvFile == NULL) {
        NSLog(@"打开YUV 文件失败");
        return;
    }
    if (self.width <= 0 || self.height <= 0) {
        NSLog(@"宽度和高度不能为 0");
        return;
    }
    
    NSLog(@"开始 拉取视频");
    while (![NSThread currentThread].isCancelled) {
        
        // 读取YUV420 planner格式的视频数据，其一帧视频数据的大小为 宽*高*3/2;
        VideoFrame *frame = (VideoFrame*)malloc(sizeof(VideoFrame));
        frame->luma = (uint8_t*)malloc(self.width * self.height);
        frame->chromaB = (uint8_t*)malloc(self.width * self.height/4);
        frame->chromaR = (uint8_t*)malloc(self.width * self.height/4);
        frame->width = self.width;
        frame->height = self.height;
        frame->cv_pixelbuffer = NULL;
        frame->full_range = 0;
        
        size_t size = fread(frame->luma, 1, self.width * self.height, yuvFile);
        size = fread(frame->chromaB, 1, self.width * self.height/4, yuvFile);
        size = fread(frame->chromaR, 1, self.width * self.height/4, yuvFile);
        
        
        if (size == 0) {
            NSLog(@"读取的数据字节为0");
            if ([self.delegate respondsToSelector:@selector(didFinishVideoData)]) {
                [self.delegate didFinishVideoData];
            }
            break;
        }
        if ([self.delegate respondsToSelector:@selector(pushYUVFrame:)]) {
            [self.delegate pushYUVFrame:frame];
        }
        
        // 写入速度比渲染速度快一些
        usleep(usec_per_fps);
    }
    NSLog(@"结束 拉取视频");
}

- (void)stop
{
    if (self.workThread) {
        [self.workThread cancel];
        self.workThread = nil;
    }
}
@end
