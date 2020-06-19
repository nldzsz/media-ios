//
//  ADAVPlayer.h
//  media
//
//  Created by Owen on 2019/5/18.
//  Copyright © 2019 Owen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import<AVFoundation/AVFoundation.h>

/** 通过AVPlayer播放音频
 *  1、需引入头文件 #import<AVFoundation/AVFoundation.h>
 *  2、比AVAudioPlayer灵活，既可以播放本地又可以播放在线音频，还可以随时获取播放进度，以及控制播放进度;
 *  3、跟AVPlayer有关的名词：
 *      Asset：AVAsset抽象类，其子类AVURLAsset可以根据URL生成包含媒体信息的Asset对象,可以获取ios所支持的容器格式
 *      AVPlayerItem：和媒体资源存在对应关系，管理媒体资源的信息和状态。
 */
@interface ADAVPlayer : NSObject

@property (strong, nonatomic) AVPlayerItem *a1PlayerItem;
@property (strong, nonatomic) id timerObserver;
@property (strong, nonatomic) AVPlayer *a1Player;

- (void)initWithURL:(NSURL*)pathUrl;
- (void)play;
- (void)stop;
@end
