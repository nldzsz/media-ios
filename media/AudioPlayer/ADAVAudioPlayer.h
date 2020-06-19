//
//  ADAVAudioPlayer.h
//  media
//
//  Created by Owen on 2019/5/18.
//  Copyright © 2019 Owen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommon.h"

/** AVAudioPlayer实现音频播放
 *  1、需引入头文件 #import<AVFoundation/AVFoundation.h>
 *  2、播放器期间实例不能释放，否则播放停止
 *  3、设置播放属性必须要在prepareToPlay方法之前
 *  4、获取音频文件的属性;时长duration 采样率，采样格式，声道数(format)，这些在initWithContentsOfURL调用之后就可以得到
 *  5、只能播放本地音频
 *  6、无法获取播放进度，无法控制播放进度
 */
@interface ADAVAudioPlayer : NSObject
@property (strong, nonatomic) AVAudioPlayer *aPlayer;

- (void)initWithPath:(NSString*)path;
- (void)play;
- (void)stop;
@end
