//
//  AudioHardCodec.h
//  media
//
//  Created by 飞拍科技 on 2019/7/18.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommon.h"

/** AudioConverterRef 格式转换器
 *  位于AudioToolbox下的AudioConvert.h中定义，它的作用如下：
 *  1、编码
 *  2、解码
 *  3、采样率/声道数/采样格式的转换
 */


@interface AudioHardCodec : NSObject
{
    // 实现音频格式(编解码)转换的核心对象
    AudioConverterRef _audioConverter;
    AudioStreamBasicDescription _sourceASBD;
    AudioStreamBasicDescription _destASBD;
    
    // 用于编码或者解码用的缓存，避免重复创建内存
    uint8_t           *_buffer;
    UInt32             _bufferSize;
}

// 将PCM数据编码为ADTS封装的AAC数据格式
- (id)initWithPCMToAAC:(AudioStreamBasicDescription)sourceASBD;

// 用于将ADTS封装的AAC数据格式解码为PCM数据
- (id)initWithAACToPCM:(AudioStreamBasicDescription)sourceASBD;

// 用于任何格式的数据转换 自己在外部定义
- (id)initWithSourceASBD:(AudioStreamBasicDescription)sourceASBD destASBD:(AudioStreamBasicDescription)destASBD;

// 将PCM数据编码为ADTS封装的AAC数据格式
- (BOOL)doEncodeBufferList:(AudioBufferList)fromBufferList toADTSData:(NSData**)todata;

// ADTS封装的AAC数据格式解码为PCM原始音频数据
- (BOOL)doDecodeBufferData:(NSData*)fromData toBufferList:(AudioBufferList*)bufList;

// 进行采样率，声道数，采样格式等的转换
- (void)doConverterBufferList:(AudioBufferList)fromBufferList toBufferList:(AudioBufferList*)toBufferList;


// 关闭转换器
- (void)colseAudioConverter;
@end
