//
//  AudioHardCodec.m
//  media
//
//  Created by 飞拍科技 on 2019/7/18.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "AudioHardCodec.h"
#define max_buffer_size (1024 * 4 * 20)

@implementation AudioHardCodec
// 将PCM数据编码为指定的格式
- (id)initWithPCMToAAC:(AudioStreamBasicDescription)sourceASBD
{
    AudioStreamBasicDescription destASBD = {0};
    destASBD.mFormatID = kAudioFormatMPEG4AAC;      // 表示AAC编码
    destASBD.mFormatFlags = kMPEG4Object_AAC_LC;    // aac 编码的 profile
    destASBD.mSampleRate = sourceASBD.mSampleRate;  // 采样率不变，与原始PCM数据保持一致
    destASBD.mChannelsPerFrame = sourceASBD.mChannelsPerFrame;  // 声道数不变，与原始PCM数据保持一致
    destASBD.mFramesPerPacket = 1024;   // 对于aac的固定码率方式 值为1024
    destASBD.mBitsPerChannel = 0;       // 填0就好
    destASBD.mBytesPerFrame = 0;        // 填0就好
    destASBD.mBytesPerPacket = 0;       // 填0就好
    destASBD.mReserved = 0;
    
    return [self initWithSourceASBD:sourceASBD destASBD:destASBD];
}

// 用于将指定编码压缩数据解码为PCM数据
- (id)initWithAACToPCM:(AudioStreamBasicDescription)sourceASBD
{
    AudioStreamBasicDescription destASBD = [ADUnitTool streamDesWithLinearPCMformat:kAudioFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked sampleRate:destASBD.mSampleRate channels:destASBD.mChannelsPerFrame bytesPerChannel:2];
    
    return [self initWithSourceASBD:sourceASBD destASBD:destASBD];
}

- (id)initWithSourceASBD:(AudioStreamBasicDescription)sourceASBD destASBD:(AudioStreamBasicDescription)destASBD
{
    if (self = [super init]) {
        
        // 创建用于格式转化的缓冲区，避免重复创建内存
        _buffer = (uint8_t*)malloc(max_buffer_size);
        _bufferSize = max_buffer_size;
        memset(_buffer, 0, _bufferSize);
        _sourceASBD = sourceASBD;
        _destASBD = destASBD;
        
        // 编码器参数
        AudioClassDescription classspecific = [self classDesWithFormatPropertyId:kAudioFormatProperty_Encoders subType:kAudioFormatMPEG4AAC manufacturer:kAppleHardwareAudioCodecManufacturer];
        // 根据指定的格式参数创建格式转换器
        CheckStatusReturn(AudioConverterNewSpecific(&sourceASBD, &destASBD, 1, &classspecific, &_audioConverter),@"AudioConverterNewSpecific fail");
//        //也可以用下面这种方式
//        const OSType subtype = kAudioFormatMPEG4AAC;
//        AudioClassDescription classspecific[2] = {
//            {
//                kAudioEncoderComponentType,
//                subtype,
//                kAppleSoftwareAudioCodecManufacturer
//            },
//        };
//        CheckStatusReturn(AudioConverterNewSpecific(&sourceASBD, &destASBD, 2, classspecific, &_audioConverter),@"AudioConverterNewSpecific fail");
    }
    return self;
}
// 将PCM数据编码为ADTS封装的AAC数据格式
- (BOOL)doEncodeBufferList:(AudioBufferList)fromBufferList toADTSData:(NSData**)todata
{
    if (!_audioConverter) {
        NSLog(@"转换器还没有创建");
        return NO;
    }
    int size = fromBufferList.mBuffers[0].mDataByteSize;
    
    if (size<= 0) {
        NSLog(@"fromBufferList 中没有数据");
        return NO;
    }
    
    // 对于编码数据来说 没有planner的概念
    UInt32  channel = fromBufferList.mBuffers[0].mNumberChannels;
    AudioBufferList outAudioBufferList = {0};
    outAudioBufferList.mNumberBuffers = 1;
    outAudioBufferList.mBuffers[0].mNumberChannels = channel;
    outAudioBufferList.mBuffers[0].mDataByteSize = _bufferSize;
    outAudioBufferList.mBuffers[0].mData = _buffer;
    UInt32 ioOutputDataPacketSize = 1;
    
    OSStatus status = AudioConverterFillComplexBuffer(_audioConverter,inInputDataProc, &fromBufferList, &ioOutputDataPacketSize,&outAudioBufferList, NULL);
    
    if (status == 0){
        NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
        NSData *adtsHeader = [self getADTSDataWithPacketLength:rawAAC.length channel:channel];
        NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
        [fullData appendData:rawAAC];
        *todata = fullData;
    }else{
        NSLog(@"音频编码失败");
        return NO;
    }
    
    return YES;
}

- (BOOL)doDecodeBufferData:(NSData*)fromData toBufferList:(AudioBufferList*)bufList
{
    if (fromData.length <=0) {
        NSLog(@"数据为空 返回");
        return NO;
    }
    Byte crcFlag;
    [fromData getBytes:&crcFlag range:NSMakeRange(1, 1)];
    // 先去掉头部
    NSData *realyData = nil;
    NSData *adtsData = nil;
    if (crcFlag & 0x08) {   // 说明ADTS头部占用7个字节
        realyData = [fromData subdataWithRange:NSMakeRange(7, fromData.length-7)];
        adtsData = [fromData subdataWithRange:NSMakeRange(0,7)];
    } else {                // 说明ADTS头部占用9个字节
        realyData = [fromData subdataWithRange:NSMakeRange(9, fromData.length-9)];
        adtsData = [fromData subdataWithRange:NSMakeRange(0,9)];
    }
    
    ADAudioFormat format = [self getADTSInfo:adtsData];
    
    AudioBufferList fromBufferlist;
    fromBufferlist.mNumberBuffers = 1;
    fromBufferlist.mBuffers[0].mNumberChannels = format.channels;
    fromBufferlist.mBuffers[0].mData = (void*)malloc(realyData.length);
    fromBufferlist.mBuffers[0].mDataByteSize = (UInt32)realyData.length;
    
    AudioBufferList outbutBufferlist;
    outbutBufferlist.mNumberBuffers = 1;
    outbutBufferlist.mBuffers[0].mNumberChannels = format.channels;
    outbutBufferlist.mBuffers[0].mData = _buffer;
    outbutBufferlist.mBuffers[0].mDataByteSize = _bufferSize;
    UInt32 ioOutputDataPacketSize = 1;
    
    OSStatus status = AudioConverterFillComplexBuffer(_audioConverter,inInputDataProc, &fromBufferlist, &ioOutputDataPacketSize,&outbutBufferlist, NULL);
    if (status != noErr) {
        NSLog(@"解码失败");
    } else {
        *bufList = outbutBufferlist;
    }
    
    return YES;
}
- (void)doConverterBufferList:(AudioBufferList)fromBufferList toBufferList:(AudioBufferList *)toBufferList
{
    
}


static OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    NSLog(@"线程2222 ==>%@",[NSThread currentThread]);
    
    AudioBufferList bufferList = *(AudioBufferList*)inUserData;
    ioData->mBuffers[0].mNumberChannels = bufferList.mBuffers[0].mNumberChannels;
    ioData->mBuffers[0].mData           = bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize   = bufferList.mBuffers[0].mDataByteSize;
    ioData->mNumberBuffers              = 1;
    
    return noErr;
}

- (void)colseAudioConverter
{
    // 关闭转换器
    if (_audioConverter) {
        AudioConverterDispose(_audioConverter);
        _audioConverter = NULL;
    }
}

/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 *  疑问：ADTS没有采样精度的描述吗？
 **/
- (NSData *)getADTSDataWithPacketLength:(NSInteger)packetLength channel:(int)channel
{
    
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC      编码压缩级别
    int freqIdx = 4;  //44.1KHz     // 采样率
    int chanCfg = channel;          // 声道数
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
//    packet[1] = (char)0xF1; // 1111 0 00 1  = syncword MPEG-4 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}

// 解析ADTS 头部的采样率，声道数等信息
- (ADAudioFormat)getADTSInfo:(NSData *)adtsData
{
    const unsigned char buff[10];
    [adtsData getBytes:(void*)buff length:adtsData.length];
    
    unsigned long long adts = 0;
    const unsigned char *p = buff;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++; adts <<= 8;
    adts |= *p ++;
    
    ADAudioFormat format;
    // 获取声道数
    format.channels = (adts >> 30) & 0x07;
    // 获取采样率
    format.samplerate = (adts >> 34) & 0x0f;
    return format;
}

/** 创建格式转换器时的参数
 */
- (AudioClassDescription)classDesWithFormatPropertyId:(AudioFormatPropertyID)formatPropertyId
                                              subType:(AudioFormatID)type
                                         manufacturer:(UInt32)manufacturer
{
    AudioClassDescription returnClassDes = {0};
    
    OSStatus status = noErr;
    // 获取指定的AudioFormatPropertyID的格式参数下inSpecifier类型为type的有多少个AudioClassDescription表示的属性
    UInt32 size;
    status = AudioFormatGetPropertyInfo(formatPropertyId, sizeof(type), &type, &size);
    if (status != noErr) {
        NSLog(@"AudioFormatGetPropertyInfo fail %d",status);
    }
    
    // 获取指定的AudioFormatPropertyID的格式参数下inSpecifier类型为type的指定数目的AudioClassDescription表示的属性
    UInt32 count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    status = AudioFormatGetProperty(formatPropertyId,
                                sizeof(type),
                                &type,
                                &size,
                                descriptions);
    if (status) {
        NSLog(@"error getting audio format propery: %d", (int)(status));
    }
    
    // 匹配指定的属性，然后拷贝过去
    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&returnClassDes, &(descriptions[i]), sizeof(returnClassDes));
        }
    }
    
    return returnClassDes;
}
@end

