//
//  ADExtAudioFile.m
//  media
//
//  Created by 飞拍科技 on 2019/7/4.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "ADExtAudioFile.h"

@implementation ADExtAudioFile
{
    // ==== 用于从文件读取数据 ==== //
    UInt32 _packetSize;
    SInt64 _totalFrames;
    BOOL   _canrepeat;
    // ==== 用于从文件读取数据 ==== //
}
// 用于读文件
- (id)initWithReadPath:(NSString*)path adsb:(AudioStreamBasicDescription)outabsd canrepeat:(BOOL)repeat
{
    if (self = [super init]) {
        _filePath = path;
        
        NSURL *fileUrl = [NSURL fileURLWithPath:_filePath];
        // 打开指定的音频文件，并且创建一个ExtAudioFileRef对象，用于读取音频数据
        OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)fileUrl, &_audioFile);
        if (status != noErr) {
            NSLog(@"ExtAudioFileOpenURL faile %d",status);
            return nil;
        }
        
        /** 通过ExtAudioFileGetProperty()函数获取文件有关属性，比如编码格式，总共的音频frames数目等等；
         *  这些步骤对于读取数据不是必须的，主要用于打印和分析
         */
        UInt32 size = sizeof(_fileDataabsdForReader);
        status = ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileDataFormat, &size, &_fileDataabsdForReader);
        if (status != noErr) {
            NSLog(@"ExtAudioFileGetProperty kExtAudioFileProperty_FileDataFormat fail %d",status);
            return nil;
        }
        size = sizeof(_packetSize);
        ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_ClientMaxPacketSize, &size, &_packetSize);
        NSLog(@"每次读取的packet的大小: %u",(unsigned int)_packetSize);
        
        // 备注：_totalFrames一定要是SInt64类型的，否则会出错。
        size = sizeof(_totalFrames);
        ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileLengthFrames, &size, &_totalFrames);
        NSLog(@"文件中包含的frame数目: %lld",_totalFrames);
        
        // 对于从文件中读数据，app属于客户端。对于向文件中写入数据，app也属于客户端
        // 设置从文件中读取数据后经过解码等步骤后最终输出的数据格式
        _clientabsdForReader = [ADUnitTool streamDesWithLinearPCMformat:outabsd.mFormatFlags sampleRate:_fileDataabsdForReader.mSampleRate channels:_fileDataabsdForReader.mChannelsPerFrame bytesPerChannel:outabsd.mBitsPerChannel/8];
        size = sizeof(_clientabsdForReader);
        status = ExtAudioFileSetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, size, &_clientabsdForReader);
        if (status != noErr) {
            NSLog(@"ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat fail %d",status);
            return nil;
        }
    }
    
    return self;
}


// 从文件中读取音频数据
- (OSStatus)readFrames:(UInt32*)framesNum toBufferData:(AudioBufferList*)bufferlist
{
    if (_canrepeat) {
        SInt64 curFramesOffset = 0;
        // 目前读取指针的postion
        if (ExtAudioFileTell(_audioFile, &curFramesOffset) == noErr) {
            
            if (curFramesOffset >= _totalFrames) {   // 已经读取完毕
                ExtAudioFileSeek(_audioFile, 0);
                curFramesOffset = 0;
            }
        }
    }
    
    OSStatus status = ExtAudioFileRead(_audioFile, framesNum, bufferlist);
    
    return status;
}


// 用于写文件
- (id)initWithWritePath:(NSString*)path adsb:(AudioStreamBasicDescription)clientabsd fileTypeId:(ADAudioFileType)typeId
{
    if (self = [super init]) {
        if (path.length == 0 || clientabsd.mBitsPerChannel == 0 || typeId == 0) {
            return nil;
        }
        
        _filePath = [path stringByDeletingPathExtension];
        _clientabsdForWriter = clientabsd;
        _fileTypeId = [ADExtAudioFile convertFromType:typeId];
        
        if ([self setupExtAudioFile] != noErr) {
            [self closeFile];
        }
    }
    return self;
}

- (OSStatus)setupExtAudioFile
{
    NSAssert([self isSurportedFileType:_fileTypeId], @"此格式还不支持");
    NSString *fileExtension = [self fileExtensionForTypeId:_fileTypeId];
    if (fileExtension == nil) {
        NSLog(@"不支持此格式 %@",fileExtension);
        return -1;
    }
    
    _filePath = [_filePath stringByAppendingPathExtension:fileExtension];
    NSURL *recordFileUrl = [NSURL fileURLWithPath:_filePath];
    NSString *fileDir = [recordFileUrl.path stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:fileDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    AudioStreamBasicDescription fileDataDesc={0};
    if (_fileTypeId == kAudioFileM4AType) {     // 保存为m4a格式音频文件
        
        fileDataDesc.mFormatID = kAudioFormatMPEG4AAC;        // m4a的编码方式为aac编码
        fileDataDesc.mFormatFlags = kMPEG4Object_AAC_Main;    // aac的编码级别为 main
        fileDataDesc.mChannelsPerFrame = _clientabsdForWriter.mChannelsPerFrame;  // 声道数和输入的PCM一致
        fileDataDesc.mSampleRate = _clientabsdForWriter.mSampleRate;  // 采样率和输入的PCM一致
        fileDataDesc.mFramesPerPacket = 1024; // 对于m4a格式aac编码方式，他压缩后每个packet包固定有1024个frame(这个值算法规定不可修改)
        fileDataDesc.mBytesPerFrame = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mBytesPerPacket = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mBitsPerChannel = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mReserved = 0;
    }   // IOS 不支持MP3的编码，尴尬
    else if(_fileTypeId == kAudioFileMP3Type) {  // 保存为mp3格式音频文件,ios不支持
        fileDataDesc.mFormatID = kAudioFormatMPEGLayer3;        // mp3的编码方式为mp3编码
        fileDataDesc.mFormatFlags = 0;    // 对于mp3来说 no flags
        fileDataDesc.mChannelsPerFrame = _clientabsdForWriter.mChannelsPerFrame;  // 声道数和输入的PCM一致
        fileDataDesc.mSampleRate = _clientabsdForWriter.mSampleRate;  // 采样率和输入的PCM一致
        fileDataDesc.mFramesPerPacket = 1152; // 对于mp3格式，他压缩后每个packet包固定有1152个frame(这个值算法规定不可修改)
        fileDataDesc.mBytesPerFrame = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mBytesPerPacket = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mBitsPerChannel = 0;// 这些填0就好，内部编码算法会自己计算
        fileDataDesc.mReserved = 0;
    }
    else if (_fileTypeId == kAudioFileCAFType || _fileTypeId == kAudioFileWAVEType) { // 保存为caf或者wav格式文件，不编码
        // 如果不做压缩，则原封不动的保存到音频文件中
        fileDataDesc.mFormatID = kAudioFormatLinearPCM;
        fileDataDesc.mFormatFlags = _clientabsdForWriter.mFormatFlags;
        fileDataDesc.mChannelsPerFrame = _clientabsdForWriter.mChannelsPerFrame;
        fileDataDesc.mSampleRate = _clientabsdForWriter.mSampleRate;
        fileDataDesc.mFramesPerPacket = _clientabsdForWriter.mFramesPerPacket;
        fileDataDesc.mBytesPerFrame = _clientabsdForWriter.mBytesPerFrame;
        fileDataDesc.mBytesPerPacket = _clientabsdForWriter.mBytesPerPacket;
        fileDataDesc.mBitsPerChannel = _clientabsdForWriter.mBitsPerChannel;
        fileDataDesc.mReserved = 0;
    } else {
        NSAssert(YES, @"此格式还不支持");
    }
    
    // 根据指定的封装格式，指定的编码方式创建ExtAudioFileRef对象
    OSStatus status = ExtAudioFileCreateWithURL((__bridge CFURLRef)recordFileUrl, _fileTypeId, &fileDataDesc, NULL, kAudioFileFlags_EraseFile, &_audioFile);
    if (status != noErr) {
        NSLog(@"ExtAudioFileCreateWithURL faile %d",status);
        return -1;
    }
    _fileDataabsdForWriter = fileDataDesc;
    
    // 指定是硬件编码还是软件编码
    UInt32 codec = kAppleSoftwareAudioCodecManufacturer;
    status = ExtAudioFileSetProperty(_audioFile, kExtAudioFileProperty_CodecManufacturer, sizeof(codec), &codec);
    if (status != noErr) {
        NSLog(@"ExtAudioFileSetProperty kExtAudioFileProperty_CodecManufacturer fail %d",status);
        return -1;
    }
    
    /** 遇到问题：返回1718449215错误；
     *  解决方案：_clientabsdForWriter格式不正确，比如ASDB中mFormatFlags与所对应的mBytesPerPacket等等不符合，那么会造成这种错误
     */
    // 指定输入给ExtAudioUnitRef的音频PCM数据格式(必须要有)
    status = ExtAudioFileSetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(_clientabsdForWriter), &_clientabsdForWriter);
    if (status != noErr) {
        NSLog(@"ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat fail %d",status);
        return -1;
    }
    
    //  ======= 检查用，非必须 ===== //
    [self checkWriterStatus];
    
    return noErr;
    
}

- (OSStatus)writeFrames:(UInt32)framesNum toBufferData:(AudioBufferList*)bufferlist
{
    return [self writeFrames:framesNum toBufferData:bufferlist async:NO];
}
- (OSStatus)writeFrames:(UInt32)framesNum toBufferData:(AudioBufferList*)bufferlist async:(BOOL)async
{
    if (_audioFile == nil) {
        NSLog(@"文件创建未成功 无法写入");
        return -1;
    }
    
    OSStatus status = noErr;
    if (async) {
         status = ExtAudioFileWriteAsync(_audioFile, framesNum, bufferlist);
    } else {
        status = ExtAudioFileWrite(_audioFile, framesNum, bufferlist);
    }
    
    return status;
}

- (AudioStreamBasicDescription)clientABSD
{
    if (_clientabsdForReader.mBitsPerChannel != 0) {
        return _clientabsdForReader;
    }
    
    return _clientabsdForWriter;
}

- (void)closeFile
{
    if (_audioFile) {
        ExtAudioFileDispose(_audioFile);
        _audioFile = nil;
    }
}

/** mp3和m4a属于压缩格式；wav和caf属于未压缩格式
 */
- (NSString*)fileExtensionForTypeId:(AudioFileTypeID)typeId
{
    switch (typeId) {
        case kAudioFileM4AType:
            return @"m4a";
            break;
        case kAudioFileWAVEType:
            return @"wav";
            break;
        case kAudioFileCAFType:
            return @"caf";
            break;
        case kAudioFileMP3Type:
            return @"mp3";
            break;
        default:
            break;
    }
    
    return nil;
}

- (BOOL)isSurportedFileType:(AudioFileTypeID)type
{
    BOOL surport = NO;
    for (NSNumber *vol in [self surportedFileTypes]) {
        if (type == [vol integerValue]) {
            surport = YES;
            break;
        }
    }
    return surport;
}

- (NSArray*)surportedFileTypes
{
    return @[@(kAudioFileM4AType),@(kAudioFileWAVEType),@(kAudioFileCAFType),@(kAudioFileMP3Type)];
}

+ (AudioFileTypeID)convertFromType:(ADAudioFileType)type
{
    NSAssert(type != ADAudioFileTypeLPCM, @"无法处理 PCM数据");
    AudioFileTypeID resultType = kAudioFileM4AType;
    if (type == ADAudioFileTypeM4A) {
        resultType = kAudioFileM4AType;
    } else if (type == ADAudioFileTypeMP3) {
        resultType = kAudioFileMP3Type;
    } else if (type == ADAudioFileTypeCAF) {
        resultType = kAudioFileCAFType;
    } else if (type == ADAudioFileTypeWAV) {
        resultType = kAudioFileWAVEType;
    } else {
        resultType = kAudioFileWAVEType;
    }
    
    return resultType;
}

- (void)checkWriterStatus
{
    AudioStreamBasicDescription fileFormat;
    UInt32 fileFmtSize = sizeof(fileFormat);
    ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_FileDataFormat, &fileFmtSize, &fileFormat);
    // fileFormat和_fileDataabsdForWriter 应该是一样的
    [ADUnitTool printStreamFormat:fileFormat];
    [ADUnitTool printStreamFormat:_fileDataabsdForWriter];
    
    // clientFormat和_clientabsdForWriter 应该是一样的
    AudioStreamBasicDescription clientFormat;
    UInt32 clientFmtSize = sizeof(clientFormat);
    ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_ClientDataFormat, &clientFmtSize, &clientFormat);
    [ADUnitTool printStreamFormat:clientFormat];
    [ADUnitTool printStreamFormat:_clientabsdForWriter];
    
    // 查看编码过程
    AudioConverterRef converter = nil;
    UInt32 dataSize = sizeof(converter);
    ExtAudioFileGetProperty(_audioFile, kExtAudioFileProperty_AudioConverter, &dataSize, &converter);
    AudioFormatListItem *formatList = nil;
    UInt32 outSize = 0;
    AudioConverterGetProperty(converter, kAudioConverterPropertyFormatList, &outSize, &formatList);
    UInt32 count = outSize / sizeof(AudioFormatListItem);
    for (int i = 0; i<count; i++) {
        AudioFormatListItem format = formatList[i];
        NSLog(@"format: %d",format.mASBD.mFormatID);
    }
}
@end
