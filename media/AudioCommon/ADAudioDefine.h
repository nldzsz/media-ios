//
//  ADAudioDefine.h
//  media
//
//  Created by 飞拍科技 on 2019/7/1.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef ADAudioDefine_h
#define ADAudioDefine_h

/** 音频采样数据的采样格式
 *  AudioFormatType16Int:
 *  对应kAudioFormatFlagIsSignedInteger，表示每一个采样数据是由16位整数来表示
 *  ADAudioFormatType32Int:
 *  对应kAudioFormatFlagIsSignedInteger，表示每一个采样数据是由32位整数来表示，播放音频时不支持
 *  AudioFormatType32Float:
 *  对应kAudioFormatFlagIsFloat，表示每一个采样数据由32位浮点数来表示
 */
typedef enum : NSUInteger {
    ADAudioFormatType16Int,
    ADAudioFormatType32Int,
    ADAudioFormatType32Float,
}ADAudioFormatType;

/** 音频采样数据在内存中的存储方式
 *  AudioSaveTypePacket:
 *  对应kAudioFormatFlagIsPacked，每个声道数据交叉存储在AudioBufferList的mBuffers
 *  [0]中,如：左声道右声道左声道右声道....
 *  AudioSaveTypePlanner:
 *  对应kAudioFormatFlagIsNonInterleaved，表示每个声道数据分开存储在mBuffers[i]中如：
 *  mBuffers[0],左声道左声道左声道左声道
 *  mBuffers[1],右声道右声道右声道右声道
 */
typedef enum : NSUInteger {
    ADAudioSaveTypePacket,
    ADAudioSaveTypePlanner,
}ADAudioSaveType;


/** 音频文件封装格式，
 *  ADAudioFileTypeLPCM 是单纯的裸PCM数据，没有音频属性数据；裸PCM数据文件不能用AudioFilePlayer和ExtAudioFileRef读写，只能用
 *  NSInputStream和NSOutputStream等流式接口进行读写
 *  ADAudioFileTypeMP3和ADAudioFileTypeM4A 用于存储压缩的音频数据
 *  ADAudioFileTypeWAV和ADAudioFileTypeCAF 用于存储未压缩音频数据
 *  IOS不支持MP3的编码？一直返回错误
 */
typedef enum : NSUInteger {
    ADAudioFileTypeLPCM,
    ADAudioFileTypeMP3,
    ADAudioFileTypeM4A,
    ADAudioFileTypeWAV,
    ADAudioFileTypeCAF
}ADAudioFileType;

typedef enum : NSUInteger {
    ADAudioEncodeTypeAAC,
    ADAudioEncodeTypeMP3,
}ADAudioEncodeType;


struct _AudioFormat {
    ADAudioFormatType formatType;
    ADAudioSaveType   saveType;
    UInt32            samplerate;
    UInt32            channels;
};
typedef struct _AudioFormat ADAudioFormat;

#endif /* ADAudioDefine_h */
