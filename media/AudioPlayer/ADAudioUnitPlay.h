//
//  ADAudioUnitPlay.h
//  media
//
//  Created by Owen on 2019/5/14.
//  Copyright © 2019 Owen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommon.h"
#import "ADExtAudioFile.h"

/** AudioUnit实现音频播放
 *  1、需引入头文件 #import<AVFoundation/AVFoundation.h>;#import <AudioToolbox/AudioToolbox.h>
 */
@interface ADAudioUnitPlay : NSObject
{
    AUGraph   _aGraph;
    
    // 小型结构体，不占用资源
    // remote IO描述体
    AudioComponentDescription _ioDes;
    AUNode    _ioNode;
    AudioUnit _ioUnit;
    
    // 格式转换器描述体
    AudioComponentDescription _cvtDes;
    AUNode    _cvtNode;
    AudioUnit _cvtUnit;
    
    // 用于播放裸PCM数据的文件句柄输送给扬声器的结构体，里面填装的音频数据
    NSInputStream *inputSteam;
    
    // 用于播放封装格式的音频文件
    ADExtAudioFile  *_readFile;
    
    BOOL            _playNonPCM;
}
@property (strong, nonatomic) ADAudioSession *aSession;

// 播放裸PCM文件，能播放的前提是要知道文件中PCM音频数据的采样率，声道数，采样位数
-(id)initWithChannels:(NSInteger)chs
           sampleRate:(CGFloat)rate
           formatType:(ADAudioFormatType)formatType
              planner:(BOOL)planner
                 path:(NSString*)path;

// 播放封装好了的音频文件 比如MP3 M4A caf音频文件等等，必须知道文件的封装格式才能播放
-(id)initWithAudioFilePath:(NSString*)path fileType:(ADAudioFileType)fileType;

- (void)play;
- (void)stop;
@end
