//
//  BaseUnitPlayer.h
//  media
//
//  Created by Owen on 2019/5/19.
//  Copyright © 2019 Owen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommon.h"

// 实现基础的播放功能
// 由于是直接播放PCM文件，该方法只有扬声器一个AudioUnit，是直接从文件中读取数据，所以以planner格式播放音频。
@interface BaseUnitPlayer : NSObject
{
    // 小型结构体，不占用资源
    // remote IO描述体
    AudioComponentDescription _ioDes;
    AudioUnit _ioUnit;
    
    NSInputStream *inputSteam;
}
@property (strong, nonatomic)ADAudioSession *dSession;

-(id)initWithChannels:(NSInteger)chs
           sampleRate:(CGFloat)rate
               format:(ADAudioFormatType)format
                 path:(NSString*)path;

-(void)play;
-(void)stop;
@end

