//
//  ADExtAudioFile.h
//  media
//
//  Created by 飞拍科技 on 2019/7/4.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommon.h"

/** 对ExtAudioFileRef读写的封装
 *  1、ExtAudioFile 是AudioUnit的一个组件，它提供了将原始音频数据编码为WAV，caff等编码格式的音频数据，同时提供写入文件的接口
 *  2、同时它还提供了从文件中读取数据解码为PCM音频数据的功能
 *  3、编码和解码支持硬编解码和软编解码
 *  4、不能操作PCM裸数据
 */
@interface ADExtAudioFile : NSObject
{
    NSString *_filePath;
    // 用于读写文件的文件句柄
    ExtAudioFileRef _audioFile;
    
    // 用于写
    AudioFileTypeID             _fileTypeId;
    AudioStreamBasicDescription _clientabsdForWriter;
    AudioStreamBasicDescription _fileDataabsdForWriter;
    
    // 用于读
    AudioStreamBasicDescription _clientabsdForReader;
    AudioStreamBasicDescription _fileDataabsdForReader;
}

/** 用于读文件
 *  path:要读取文件的路径
 *  clientabsd:从文件中读取数据后的输出给app的音频数据格式，函数内部会使用实际的采样率和声道数，这里只需要指定采样格式和存储方式(planner还是packet)
 *  repeat:当到达文件的末尾后，是否重新开始读取
 */
- (id)initWithReadPath:(NSString*)path adsb:(AudioStreamBasicDescription)clientabsd canrepeat:(BOOL)repeat;
- (OSStatus)readFrames:(UInt32*)framesNum toBufferData:(AudioBufferList*)bufferlist;


/** 用于写文件
 *  path:要写入音频数据的文件路径
 *  clientabsd:由APP端传输给Unit的音频数据格式(此时是PCM数据),然后Unit内部会经过编码再写入文件
 *  typeId:指定封装格式(每一个封装格式对应特定的一种或几种编码方式)
 *  async:是否异步写入数据，默认同步写入
 */
- (id)initWithWritePath:(NSString*)path adsb:(AudioStreamBasicDescription)clientabsd fileTypeId:(ADAudioFileType)typeId;
- (OSStatus)writeFrames:(UInt32)framesNum toBufferData:(AudioBufferList*)bufferlist;
- (OSStatus)writeFrames:(UInt32)framesNum toBufferData:(AudioBufferList*)bufferlist async:(BOOL)async;

- (AudioStreamBasicDescription)clientABSD;

- (void)closeFile;


+ (AudioFileTypeID)convertFromType:(ADAudioFileType)type;
@end
