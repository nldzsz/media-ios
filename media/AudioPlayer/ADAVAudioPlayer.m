//
//  ADAVAudioPlayer.m
//  media
//
//  Created by Owen on 2019/5/18.
//  Copyright © 2019 Owen. All rights reserved.
//

#import "ADAVAudioPlayer.h"

@implementation ADAVAudioPlayer
- (void)initWithPath:(NSString*)path
{
    // 外链文件无法播放
    //    path = @"https://img.flypie.net/test-mp3-1.mp3";
    NSURL *playUrl = [NSURL URLWithString:path];
    self.aPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:playUrl error:nil];
    if (!self.aPlayer) {
        NSLog(@"audioPlayer is nil");
        return;
    }
    NSLog(@"channels %ld duraiotn %.0f fomat %lu",self.aPlayer.numberOfChannels,self.aPlayer.duration,self.aPlayer.format.commonFormat);
    
    // 播放音量
    self.aPlayer.volume = 0.5;
    // 修改左右声道的平衡（默认0.0，可设置范围为-1.0至1.0，两个极端分别为只有左声道、只有右声道）
    self.aPlayer.pan = -1;
    // 开启设置播放速度，此项必须打开下面设置rate才有效
    self.aPlayer.enableRate = YES;
    // 设置播放速度（默认1.0，可设置范围为0.5至2.0，两个极端分别为一半速度、两倍速度）：
    self.aPlayer.rate = 2.0;
    // 设置循环播放（默认1，若设置值大于0，则为相应的循环次数，设置为-1可以实现无限循环）：
    self.aPlayer.numberOfLoops = -1;
    
    // 提前获取需要的硬件支持，并加载音频到缓冲区。在调用play方法时，减少开始播放的延迟。
    [self.aPlayer prepareToPlay];
}

- (void)play
{
    if (self.aPlayer) {
        [self.aPlayer play];
    }
}

- (void)stop
{
    if (self.aPlayer) {
        [self.aPlayer stop];
    }
}
@end
