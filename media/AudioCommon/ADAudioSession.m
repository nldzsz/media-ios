//
//  ADAudioSession.m
//  media
//
//  Created by Owen on 2019/5/19.
//  Copyright © 2019 Owen. All rights reserved.
//

#import "ADAudioSession.h"
// 三种不同音频播放延迟
const NSTimeInterval AUSAudioSessionDelay_Background = 0.0929;
const NSTimeInterval AUSAudioSessionDelay_Default = 0.0232;
const NSTimeInterval AUSAudioSessionDelay_Low = 0.0058;

@implementation ADAudioSession
- (instancetype)init
{
    return [self initWithCategary:AVAudioSessionCategoryPlayback channels:2 sampleRate:44100 bufferDuration:AUSAudioSessionDelay_Low*4 fortmatType:ADAudioFormatType16Int saveType:ADAudioSaveTypePacket];
}
-(instancetype)initWithCategary:(AVAudioSessionCategory)category
                       channels:(NSInteger)chs
                     sampleRate:(double)rate
                 bufferDuration:(NSTimeInterval)duration
                    fortmatType:(ADAudioFormatType)formatType
                       saveType:(ADAudioSaveType)saveType
{
    return [self initWithCategary:AVAudioSessionCategoryPlayback channels:2 sampleRate:44100 bufferDuration:AUSAudioSessionDelay_Low*4 fortmatType:ADAudioFormatType16Int saveType:ADAudioSaveTypePacket isBigEndian:NO];
}

-(instancetype)initWithCategary:(AVAudioSessionCategory)category
      channels:(NSInteger)chs
    sampleRate:(double)rate
bufferDuration:(NSTimeInterval)duration
   fortmatType:(ADAudioFormatType)formatType
      saveType:(ADAudioSaveType)saveType
   isBigEndian:(BOOL)bigEndian
{
    if (self = [super init]) {
        /** AVAudioSession 是一个单例，表示一个音频会话，不管录制音频还是播放音频都需要这样一个音频会话，它表示要播放和要录制音频的属性，比如：
         *  采样率，采样格式，存储方式，编码方式，缓冲区延迟等等。
         */
        self.currentSampleRate = rate;
        // 要采集或者播放音频的声道数
        self.currentChannels = chs;
        
        // 采样格式
        self.formatType = formatType;
        // 存储格式
        self.saveType = saveType;
        // 是否大端序
        self.bigEndian = bigEndian;
        // 1、创建一个音频会话 它是单例；AVAudioSession 在AVFoundation/AVFAudio/AVAudioSession.h中定义
        _aSession = [AVAudioSession sharedInstance];
        
        //  2、======配置音频会话 ======//
        /** 配置使用的音频硬件:
         *  AVAudioSessionCategoryPlayback:只是进行音频的播放(只使用听的硬件，比如手机内置喇叭，或者通过耳机)
         *  AVAudioSessionCategoryRecord:只是采集音频(只录，比如手机内置麦克风)
         *  AVAudioSessionCategoryPlayAndRecord:一边采集一遍播放(听和录同时用)
         */
        [_aSession setCategory:category error:nil];
        
        // 设置采样率，不管是播放还是录制声音 都需要设置采样率
        [_aSession setPreferredSampleRate:rate error:nil];
        
        // 设置I/O的Buffer，数值越小说明缓存的数据越小，延迟也就越低；
        [_aSession setPreferredIOBufferDuration:duration error:nil];
        
        // 激活会话
        [_aSession setActive:YES error:nil];
    }
    
    return self;
}

- (BOOL)isPlanner
{
    return self.saveType == ADAudioSaveTypePlanner;
}

- (AudioFormatFlags)formatFlags
{
    AudioFormatFlags flags = kAudioFormatFlagIsSignedInteger;
    if (self.formatType == ADAudioFormatType32Float) {
        flags = kAudioFormatFlagIsFloat;
    }
    
    if (self.isPlanner) {
        flags |= kAudioFormatFlagIsNonInterleaved;
    } else {
        flags |= kAudioFormatFlagIsPacked;
    }
    
    if (self.bigEndian) {
        return flags | kAudioFormatFlagIsBigEndian;
    }
    
    return flags;
}

- (NSInteger)bytesPerChannel
{
    if (self.formatType == ADAudioFormatType16Int) {
        return 2;
    }
    return 4;
}

@end
