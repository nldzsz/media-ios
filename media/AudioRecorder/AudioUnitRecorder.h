//
//  AudioUnitRecorder.h
//  media
//
//  Created by 飞拍科技 on 2019/6/24.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommon.h"
#import "AudioDataWriter.h"
#import "ADExtAudioFile.h"

/** 本类设计的目的需求为
 *  1、实现音频录制
 *  2、将录制的音频数据编码然后保存到文件中
 */
@interface AudioUnitRecorder : NSObject
{
    AUGraph _augraph;
    
    // remoteIO Unit 用于麦克风和扬声器
    AudioComponentDescription   _iodes;
    AUNode                      _ioNode;
    AudioUnit                   _ioUnit;
    
    // 格式转化 Unit
    AudioComponentDescription   _convertdes;
    AUNode                      _convertNode;
    AudioUnit                   _convertUnit;
    
    // 混音器
    AudioComponentDescription   _mixerDes;
    AUNode                      _mixerNode;
    AudioUnit                   _mixerUnit;
    
    AudioBufferList *           _bufferList;
    
    // 是否开启了混音
    BOOL _enableMixer;
    NSString *_mixerPath;
    AudioStreamBasicDescription _mixerStreamDesForInput;    // 混音器的输入数据格式
    AudioStreamBasicDescription _mixerStreamDesForOutput;    // 混音器的输出数据格式
    
    // 是否耳返
    BOOL _isEnablePlayWhenRecord;
}
@property (strong, nonatomic)ADAudioSession  *audioSession;

// 用于写裸PCM数据到音频文件中
@property (strong, nonatomic)AudioDataWriter *dataWriteForPCM;
// 用于将录制的音频写入指定的封装格式
@property (strong, nonatomic)ADExtAudioFile *dataWriteForNonPCM;

// 用于读取背景音乐文件
@property (strong, nonatomic)ADExtAudioFile *dataReader;
/** 录音并且保存到文件中
 *  channels，samplerate，代表了录制的音频的参数
 *  savePath表示录制音频存储的路径，如果为nil 则不保存
 */
- (id)initWithFormatType:(ADAudioFormatType)formatType
                 planner:(BOOL)planner
                channels:(NSInteger)chs
              samplerate:(CGFloat)sampleRate
                    Path:(NSString*)savePath
            saveFileType:(ADAudioFileType)fileType;

/** 录制音频并
 *  是否开启耳返效果
 *  在麦克风录制声音的同时又将声音从扬声器播放出来，此功能称为边录边播。不过要注意的是，此功能得带上耳机才有很好的体验效果。否则
 *  像拖拉机一样
 *  savePath表示录制音频存储的路径，如果为nil 则不保存
 */
- (id)initWithFormatType:(ADAudioFormatType)formatType
                 planner:(BOOL)planner
                channels:(NSInteger)chs
              samplerate:(CGFloat)sampleRate
                    Path:(NSString*)savePath
           recordAndPlay:(BOOL)yesOrnot
            saveFileType:(ADAudioFileType)fileType;

/** 录制音频
 *  是否开启耳返效果
 *  是否播放背景音乐，backgroundPath为nil则不播放，否则在录制时还会播放指定路径的背景音乐
 *  savePath表示录制音频存储的路径，如果为nil 则不保存
 */
- (id)initWithFormatType:(ADAudioFormatType)formatType
                 planner:(BOOL)planner
                channels:(NSInteger)chs
              samplerate:(CGFloat)sampleRate
                    Path:(NSString*)savePath
     backgroundMusicPath:(NSString*)backgroundPath
           recordAndPlay:(BOOL)yesOrnot
            saveFileType:(ADAudioFileType)fileType;


- (void)startRecord;
- (void)stopRecord;

@end
