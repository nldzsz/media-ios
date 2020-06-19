//
//  ADAVPlayer.m
//  media
//
//  Created by Owen on 2019/5/18.
//  Copyright © 2019 Owen. All rights reserved.
//

#import "ADAVPlayer.h"

@implementation ADAVPlayer

- (void)initWithURL:(NSURL*)pathUrl
{
    // 查询支持的容器格式
    //    NSLog(@"surport formats %@",[AVURLAsset audiovisualMIMETypes]);
    
    // 用asset来初始化player；也可以直接用URL来初始化
    self.a1PlayerItem = [[AVPlayerItem alloc] initWithURL:pathUrl];
    self.a1Player = [[AVPlayer alloc] initWithPlayerItem:_a1PlayerItem];
    if (!self.a1Player) {
        NSLog(@"AVPlayer init fail");
        return;
    }
    
    // 设置播放音量
    self.a1Player.volume = 0.5;
    // 设置播放速度
    self.a1Player.rate = 2.0;
    // 从指定时间开始播放
    [self.a1Player seekToTime:CMTimeMake(3.0, 1)];
    
    /** 设置监听；注意不设置这些监听也可以正常播放，即从头播放到尾   **///
    // 1.通过KVO监听媒体资源加载状态
    [_a1PlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    // 2.通过KVO监听数据缓冲状态
    [_a1PlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    // 3.通过block回调监听播放进度
    __weak typeof(self) weakSelf = self;
    self.timerObserver = [self.a1Player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        float current = CMTimeGetSeconds(time);
        float total = CMTimeGetSeconds(weakSelf.a1PlayerItem.duration);
        NSLog(@"播放进度 %.0f total%.0f",current,total);
    }];
    

    // 添加播放完成的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:_a1PlayerItem];
}

- (void)play
{
    if (self.a1Player) {
        // 播放
        [self.a1Player play];
        // 替换当前播放资源;此功能可以用来播放上一首下一首
        //    [self.a1Player replaceCurrentItemWithPlayerItem:item];
    }
}

- (void)stop
{
    if (self.a1Player) {
        [self.a1Player pause];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]) {
        switch (self.a1Player.status) {
            case AVPlayerStatusUnknown:
            {
                NSLog(@"未知转态");
            }
                break;
            case AVPlayerStatusReadyToPlay:
            {
                NSLog(@"准备播放");
            }
                break;
            case AVPlayerStatusFailed:
            {
                NSLog(@"加载失败");
            }
                break;
                
            default:
                break;
        }
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        AVPlayerItem * songItem = object;
        NSArray * array = songItem.loadedTimeRanges;
        CMTimeRange timeRange = [array.firstObject CMTimeRangeValue]; //本次缓冲的时间范围
        NSTimeInterval totalBuffer = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration); //缓冲总长度
        NSLog(@"共缓冲%.2f",totalBuffer);
    }
}

- (void)playbackFinished:(NSNotification*)noti
{
    NSLog(@"播放完成");
    [self.a1PlayerItem removeObserver:self forKeyPath:@"status"];
    [self.a1PlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.timerObserver) {
        [self.a1Player removeTimeObserver:self.timerObserver];
    }
}
@end
