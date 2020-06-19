//
//  YuvPlayer.h
//  media
//
//  Created by 飞拍科技 on 2019/6/8.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GLDefine.h"
#import "VideoFileSource.h"
#import "GLVideoView.h"

@interface YuvPlayer : NSObject<VideoFileSourceProtocol>

@property (strong, nonatomic) GLVideoView *renderView;
// 单例
+ (instancetype)shareInstance;

// 设置显示视频的视图父视图，真正渲染视频的UIView将在该视图内
- (void)setVideoView:(UIView*)videoView;

- (void)play;
- (void)stop;

@end
