//
//  ADUnitTool.m
//  media
//
//  Created by Owen on 2019/5/19.
//  Copyright © 2019 Owen. All rights reserved.
//

#import "ADUnitTool.h"

@implementation ADUnitTool
/**
 *  与AudioUnit有关的错误类型枚举定义在AudioToolbox/AUComponent.h文件中
 *  CF_ENUM(OSStatus) {
 *      kAudioUnitErr_InvalidProperty            = -10879,
 *      .......
 *  }
 */
/** AudioUnit的类型,定义在AudioToolbox/AUComponent.h文件中
 *  CF_ENUM(UInt32) {
 kAudioUnitType_Output                    = 'auou',
 kAudioUnitType_MusicDevice               = 'aumu',
 kAudioUnitType_MusicEffect               = 'aumf',
 kAudioUnitType_FormatConverter           = 'aufc',
 kAudioUnitType_Effect                    = 'aufx',
 kAudioUnitType_Mixer                     = 'aumx',
 kAudioUnitType_Panner                    = 'aupn',
 kAudioUnitType_Generator                 = 'augn',
 kAudioUnitType_OfflineEffect             = 'auol',
 kAudioUnitType_MIDIProcessor             = 'aumi'
 };
 *  常用类型如下：
 *  1、kAudioUnitType_Effect;主要用于提供声音特效的处理，包括的子类型有
 *   .均衡效果器:kAudioUnitSubType_NBandEQ，用于为声音的某些频带增强或减弱能量
 *   .压缩效果器:kAudioUnitSubType_DynamicsProcessor,增大或者减少音量
 *   .混响效果器:kAudioUnitSubType_Reverb2,提供混响效果
 *   ....
 *  2、kAudioUnitType_Mixer:提供Mix多路声音功能
 *   .多路混音效果器:kAudioUnitSubType_MultiChannelMixer，可以接受多路音频的输入，然后分别调整每一路音频的增益与开关，并将多路音频合成一路
 *  3、kAudioUnitType_Output:提供音频的录制，播放功能
 *   .录制和播放音频:kAudioUnitSubType_RemoteIO,后面通过AudioUnitSetProperty()方法具体是访问麦克风还是扬声器
 *   .访问音频数据:kAudioUnitSubType_GenericOutput
 *  4、kAudioUnitType_FormatConverter:提供音频格式转化功能,比如采样率转换，声道数转换，采样格式转化，panner到packet转换等等
 *   .kAudioUnitSubType_AUConverter:提供格式转换功能
 *   .kAudioUnitSubType_AudioFilePlayer:直接从文件获取输入音频数据，它具有解码功能
 *   .kAudioUnitSubType_NewTimePitch:变速变调效果器
 */
// 创建指定的类型
+ (AudioComponentDescription)comDesWithType:(OSType)type subType:(OSType)subType fucture:(OSType)manufuture
{
    AudioComponentDescription acd;
    acd.componentType = type;
    acd.componentSubType = subType;
    acd.componentManufacturer = manufuture;
    return acd;
}

/** AudioStreamBasicDescription详解，它用来描述对应的AudioUnit在处理数据时所需要的数据格式
 *  mSampleRate:音频的采样率，一般有44.1khz，48khz等
 *  mFormatID:编码类型，比如一般采集的原始音频编码就为kAudioFormatLinearPCM
 *  mFormatFlags:采样格式及存储方式，ios支持两种采样格式(Float，32位，Signed Integer 16)；存储方式就是(Interleaved)Packet和(NonInterleaved)Planner，前者表示每个声道
    数据交叉存储在AudioBufferList的mBuffers[0]中，后者表示每个声道数据分开存储在mBuffers[i]中
 *  mBitsPerChannel:每个声道所占位数，32(因为ios只有32位的采样格式);一个声道就是一个采样
 *  mChannelsPerFrame:每个Frame的声道数；Packet格式，一个Frame包含多个声道，Planner格式，一个Frame包含一个声道
 *  mBytesPerFrame:每个Frame的字节数，对于packet包，因为是交叉存储，所以一个frame中有n个channels，计算公式为：
 *  =mBitsPerChannel/8*channels；对于planner， 计算公式为：=mBitsPerChannel/8
 *  mFramesPerPacket:每个Packet的Frame数目；对于原始数据，一个packet就是包含一个frame；对于压缩数据，一个packet
 *  包含多个frame(不同编码类型，数目不一样，比如aac编码，一个packet包含1024个frame)
 *  mBytesPerPacket:每个Packet的字节数，计算公式为：=mBytesPerFrame*mFramesPerPacket
 *
 *  Tips：
 *  一个Packet对应AudioBufferList的mBuffers中的一个元素，每个Packet包含一个或者多个Frame，每个Frame包含一个
 *  或者多个Channel，一个Channel就是一个采样。
 */
+ (AudioStreamBasicDescription)streamDesWithLinearPCMformat:(AudioFormatFlags)flags
                                                 sampleRate:(CGFloat)rate
                                                   channels:(NSInteger)chs
                                            bytesPerChannel:(NSInteger)bytesPerChann
{
    
    UInt32 bytesPerChannel = (UInt32)(bytesPerChann);
    BOOL isPlanner = flags & kAudioFormatFlagIsNonInterleaved;
    
    AudioStreamBasicDescription asbd;
    bzero(&asbd, sizeof(asbd));
    asbd.mSampleRate = rate;   // 采样率
    asbd.mFormatID = kAudioFormatLinearPCM; // 编码格式
    asbd.mFormatFlags = flags;//采样格式及存储方式
    asbd.mBitsPerChannel = 8 * bytesPerChannel;
    asbd.mChannelsPerFrame = (UInt32)chs; // 声道数
    if (isPlanner) {
        asbd.mBytesPerFrame = bytesPerChannel;//planner格式 每个Frame只是包含一个Channel
        asbd.mFramesPerPacket = 1; // 因为前面是kAudioFormatLinearPCM编码格式，所以一个packet中只有一个frame
        asbd.mBytesPerPacket = asbd.mFramesPerPacket*asbd.mBytesPerFrame;
    } else {
        asbd.mBytesPerFrame = (UInt32)chs*bytesPerChannel;//packet格式 每个frame包含多个Channel
        asbd.mFramesPerPacket = 1; // 因为前面是kAudioFormatLinearPCM编码格式，所以一个packet中只有一个frame
        asbd.mBytesPerPacket = asbd.mFramesPerPacket*asbd.mBytesPerFrame;
    }
    
    return asbd;
}

+ (void)printStreamFormat:(AudioStreamBasicDescription)streamASDB
{
    BOOL isPlanner = streamASDB.mFormatFlags & kAudioFormatFlagIsNonInterleaved;
    BOOL isInteger = streamASDB.mFormatFlags & kAudioFormatFlagIsSignedInteger;
    char formatIdChars[5];
    UInt32 nativeFormatId = CFSwapInt32BigToHost(streamASDB.mFormatID);
    memcpy(formatIdChars, &nativeFormatId, 4);
    formatIdChars[4] = '\0';
    NSLog(@"planner %d integer %d formatID %s channels %d bytesPerChannel %d bytesPerFrame %d bytesPerPacket %d",isPlanner,isInteger,formatIdChars,streamASDB.mChannelsPerFrame,streamASDB.mBitsPerChannel/8,streamASDB.mBytesPerFrame,streamASDB.mBytesPerPacket);
}
@end
