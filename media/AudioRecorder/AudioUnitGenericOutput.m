//
//  AudioUnitGenericOutput.m
//  media
//
//  Created by 飞拍科技 on 2019/7/10.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

// 参考文档
// https://stackoverflow.com/questions/13309103/augraph-record-and-play-with-remoteio-and-multichannelmixer
// https://stackoverflow.com/questions/15153008/pull-audio-data-from-graph-kaudiounitsubtype-genericoutput#


#import "AudioUnitGenericOutput.h"

@implementation AudioUnitGenericOutput

- (id)initWithPath1:(NSString*)path1 volume:(float)vol1 path2:(NSString*)path2 volume:(float)vol2;
{
    if (self = [super init]) {
        self.source1 = path1;
        self.source2 = path2;
        _volume[0] = vol1 == 0.0?1.0:vol1;
        _volume[1] = vol2 == 0.0?1.0:vol2;
    }
    return self;
}

- (void)setupFormat:(ADAudioFormatType)format
      audioSaveType:(ADAudioSaveType)saveType
         sampleRate:(UInt32)samplerate
           channels:(UInt32)channels
           savePath:(NSString*)savePath
       saveFileType:(ADAudioFileType)type
{
    AudioStreamBasicDescription clientABSD;
    AudioFormatFlags flags;
    UInt32 bytesPerChannel = 2;
    if (format == ADAudioFormatType16Int) {
        flags = kAudioFormatFlagIsSignedInteger | ((saveType==ADAudioSaveTypePlanner)?kAudioFormatFlagIsNonInterleaved:kAudioFormatFlagIsPacked);
    } else if(format == ADAudioFormatType32Int){
        flags = kAudioFormatFlagIsSignedInteger | ((saveType==ADAudioSaveTypePlanner)?kAudioFormatFlagIsNonInterleaved:kAudioFormatFlagIsPacked);
        bytesPerChannel = 4;
    } else {
        flags = kAudioFormatFlagIsFloat | ((saveType==ADAudioSaveTypePlanner)?kAudioFormatFlagIsNonInterleaved:kAudioFormatFlagIsPacked);
        bytesPerChannel = 4;
    }
    clientABSD = [ADUnitTool streamDesWithLinearPCMformat:flags sampleRate:samplerate channels:channels bytesPerChannel:bytesPerChannel];
    
    if (type == ADAudioFileTypeLPCM) {
        _dataWriteForPCM = [[AudioDataWriter alloc] initWithPath:savePath];
    } else {
        _extFileWriter = [[ADExtAudioFile alloc] initWithWritePath:savePath adsb:clientABSD fileTypeId:type];
    }
    _clientABSD = clientABSD;
    
    [self setupAUGraph];
    [self setupSource:_source1 sourceFileID:_source1FileID player:_source1Unit];
    [self setupSource:_source2 sourceFileID:_source2FileID player:_source2Unit];
}

- (void)setupAUGraph
{
    OSStatus status;
    CheckStatusReturn(NewAUGraph(&_auGraph),@"NewAUGraph error ");
    
    /** kAudioUnitSubType_AudioFilePlayer和ExtAudioUnitRef的区别
     *  对于从文件中读取数据，后者是对前者的封装
     *  同时后者还封装了写数据到文件中
     *  共同点就是两者都只能操作带有属性信息的音频封装文件，比如M4A，MP3，对于裸数据PCM文件则无法操作
     */
    AudioComponentDescription source1 = [ADUnitTool comDesWithType:kAudioUnitType_Generator subType:kAudioUnitSubType_AudioFilePlayer fucture:kAudioUnitManufacturer_Apple];
    CheckStatusReturn(AUGraphAddNode(_auGraph, &source1, &_source1Node),@"AUGraphAddNode _source1Node error");
    
    AudioComponentDescription source2 = [ADUnitTool comDesWithType:kAudioUnitType_Generator subType:kAudioUnitSubType_AudioFilePlayer fucture:kAudioUnitManufacturer_Apple];
    CheckStatusReturn(AUGraphAddNode(_auGraph, &source2, &_source2Node),@"AUGraphAddNode _source2Node");
    
    AudioComponentDescription mixer = [ADUnitTool comDesWithType:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer fucture:kAudioUnitManufacturer_Apple];
    CheckStatusReturn(AUGraphAddNode(_auGraph, &mixer, &_mixerNode),@"AUGraphAddNode _mixerNode error");
    
    AudioComponentDescription generic = [ADUnitTool comDesWithType:kAudioUnitType_Output subType:kAudioUnitSubType_GenericOutput fucture:kAudioUnitManufacturer_Apple];
    CheckStatusReturn(AUGraphAddNode(_auGraph, &generic, &_genericNode),@"AUGraphAddNode _genericNode error");
    
    status = AUGraphOpen(_auGraph);
    if (status != noErr) {
        NSLog(@"AUGraphOpen error %d",status);
        return;
    }
    
    status = AUGraphNodeInfo(_auGraph, _source1Node, &source1, &_source1Unit);
    if (status != noErr) {
        NSLog(@"AUGraphNodeInfo _source1Unit error %d",status);
        return;
    }
    status = AUGraphNodeInfo(_auGraph, _source2Node, &source1, &_source2Unit);
    if (status != noErr) {
        NSLog(@"AUGraphNodeInfo _source2Unit error %d",status);
        return;
    }
    status = AUGraphNodeInfo(_auGraph, _mixerNode, &mixer, &_mixerUnit);
    if (status != noErr) {
        NSLog(@"AUGraphNodeInfo _mixerUnit error %d",status);
        return;
    }
    status = AUGraphNodeInfo(_auGraph, _genericNode, &generic, &_genericUnit);
    if (status != noErr) {
        NSLog(@"AUGraphNodeInfo _genericUnit error %d",status);
        return;
    }
    
    // 从音频文件中读取数据解码后的音频数据格式;经过测试，发现只支持AudioFilePlayer解码后输出的数据格式只支持
    // kAudioFormatFlagIsFloat|kAudioFormatFlagIsNonInterleaved;
    AudioFormatFlags flags = kAudioFormatFlagIsFloat|kAudioFormatFlagIsNonInterleaved;
    AudioStreamBasicDescription inputASDB = [ADUnitTool streamDesWithLinearPCMformat:flags sampleRate:44100 channels:2 bytesPerChannel:4];
    CheckStatusReturn(AudioUnitSetProperty(_source1Unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &inputASDB, sizeof(inputASDB)), @"AudioUnitSetProperty _source1Unit output");
    CheckStatusReturn(AudioUnitSetProperty(_source2Unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &inputASDB, sizeof(inputASDB)), @"AudioUnitSetProperty _source2Unit output");
    
   
    // 配置混音器的输入bus 数目
    UInt32 busCount   = 2;    // bus count for mixer unit input
    AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount));
    
    //Enable metering mode to view levels input and output levels of mixer
    UInt32 onvalue = 1;
    AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Input, 0, &onvalue, sizeof(onvalue));
    
    // 设置mixer unit单元每次处理(调用AudioUnitRender()函数时)frames的最大数目，一般混音器设置，kAudioUnitScope_Global代表对输入和输出都有效
    UInt32 maximumFramesPerSlice = 4096;
    CheckStatusReturn(AudioUnitSetProperty(_mixerUnit,kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, sizeof(maximumFramesPerSlice)), @"AudioUnitSetProperty maximumFramesPerSlice");
    
    // 混音器输入接口的数据格式
    CheckStatusReturn(AudioUnitSetProperty(_mixerUnit,kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &inputASDB, sizeof(inputASDB)), @"AudioUnitSetProperty inputASDB");
    CheckStatusReturn(AudioUnitSetProperty(_mixerUnit,kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &inputASDB, sizeof(inputASDB)), @"AudioUnitSetProperty inputASDB");
    
    // 设置各路音频混合后的音量
    CheckStatusReturn(AudioUnitSetParameter(_mixerUnit,kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, _volume[0], 0), @"AudioUnitSetProperty inputASDB");
    CheckStatusReturn(AudioUnitSetParameter(_mixerUnit,kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 1, _volume[1], 0), @"AudioUnitSetProperty inputASDB");
    
    /** 遇到问题：混音器的输出格式 无法设置？一直返回-108868，但是也不影响结果。
     *  分析原因：想一下也正确，因为混音器的输出格式肯定和输入格式一样
     *  解决方案：去掉混音器输出格式设置，对结果不影响
     */

//    CheckStatusReturn(AudioUnitSetProperty(_mixerUnit,kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mixerASBD, sizeof(mixerASBD)), @"AudioUnitSetProperty outputASBD");
    
    // 设置generic output 输入输出数据格式
    AudioStreamBasicDescription mixerASBD = _clientABSD;
    CheckStatusReturn(AudioUnitSetProperty(_genericUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mixerASBD, sizeof(mixerASBD)),@"AudioUnitSetProperty outputASBD1");
    CheckStatusReturn(AudioUnitSetProperty(_genericUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mixerASBD, sizeof(mixerASBD)),@"AudioUnitSetProperty outputASBD2");
    
    // 将文件1和文件2的音频 输入mixer进行混音处理
    CheckStatusReturn(AUGraphConnectNodeInput(_auGraph, _source1Node, 0, _mixerNode, 0), @"AUGraphConnectNodeInput 1");
    CheckStatusReturn(AUGraphConnectNodeInput(_auGraph, _source2Node, 0, _mixerNode, 1),@"AUGraphConnectNodeInput 2");
    // 将混音的结果作为generic out的输入
    CheckStatusReturn(AUGraphConnectNodeInput(_auGraph, _mixerNode, 0, _genericNode, 0),@"AUGraphConnectNodeInput _genericNode");
    
    // 初始化
    CheckStatusReturn(AUGraphInitialize(_auGraph),@"AUGraphInitialize error ");
}

- (void)setupSource:(NSString*)sourcePath sourceFileID:(AudioFileID)sourceFileID player:(AudioUnit)sourceplayer
{
    CFURLRef sourceUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:sourcePath];
    
    // 打开文件，并生成一个文件句柄sourceFileID;第三个参数表示文件的封装格式后缀，如果为0，表示自动检测
    CheckStatusReturn(AudioFileOpenURL(sourceUrl, kAudioFileReadPermission, 0, &sourceFileID), @"AudioFileOpenURL fail");
    
    // 获取文件本身的数据格式(根据文件的信息头解析，未解压的，根据文件属性获取)
    AudioStreamBasicDescription fileASBD;
    UInt32 propSize = sizeof(fileASBD);
    CheckStatusReturn(AudioFileGetProperty(sourceFileID, kAudioFilePropertyDataFormat,&propSize, &fileASBD),
               @"setUpAUFilePlayer couldn't get file's data format");
    
    /** 遇到问题：获取音频文件中packet数目时返回kAudioFileBadPropertySizeError错误
     *  解决方案：kAudioFilePropertyAudioDataPacketCount的必须是UInt64 类型，替换即可
     */
    // 获取文件中的音频packets数目
    UInt64 nPackets;
    propSize = sizeof(nPackets);
    CheckStatusReturn(AudioFileGetProperty(sourceFileID, kAudioFilePropertyAudioDataPacketCount,&propSize, &nPackets),
               @"setUpAUFilePlayer AudioFileGetProperty[kAudioFilePropertyAudioDataPacketCount] failed");
    
    // 指定要播放的文件句柄;要想成功读取音频文件中数据，先要将该文件加入指定的AudioUnit中(AudioFilePlayer AudioUnit)
    CheckStatusReturn(AudioUnitSetProperty(sourceplayer, kAudioUnitProperty_ScheduledFileIDs,
                                           kAudioUnitScope_Global, 0, &sourceFileID, sizeof(sourceFileID)),
                      @"setUpAUFilePlayer AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileIDs] failed");
    
    // 指定从音频在读取数据的方式;前面将要播放的文件加入了AudioUnit，这里指定要播放的范围(比如是播放整个文件还是播放部分文件)，播放方式
    // (比如是否循环播放)等等
    ScheduledAudioFileRegion rgn;
    memset(&rgn.mTimeStamp, 0, sizeof(rgn.mTimeStamp));
    rgn.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid; // 播放整个文件，这里必须为此值
    rgn.mTimeStamp.mSampleTime = 0;                         // 播放整个文件，这里必须为此值
    rgn.mCompletionProc = NULL; // 数据读取完毕之后的回调函数
    rgn.mCompletionProcUserData = NULL; // 传给回调函数的对象
    rgn.mAudioFile = sourceFileID;  // 要读取的文件句柄
    rgn.mLoopCount = 0;    // 是否循环读取，0不循环，-1 一直循环 其它值循环的具体次数
    rgn.mStartFrame = 0;    // 读取的起始的frame 索引
    rgn.mFramesToPlay = (UInt32)nPackets * fileASBD.mFramesPerPacket;   // 从读取的起始frame 索引开始，总共要读取的frames数目
    if (_totalFrames < rgn.mFramesToPlay) {
        _totalFrames = rgn.mFramesToPlay;
    }
    
    /** 遇到问题：返回-10867
     *  解决思路：设置kAudioUnitProperty_ScheduledFileRegion前要先调用AUGraphInitialize
     *  (_auGraph);初始化AUGraph
     */
    CheckStatusReturn(AudioUnitSetProperty(sourceplayer, kAudioUnitProperty_ScheduledFileRegion,
                                    kAudioUnitScope_Global, 0,&rgn, sizeof(rgn)),
               @"setUpAUFilePlayer AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion] failed");
    
    // 指定从音频文件中读取音频数据的行为，必须读取指定的frames数(也就是defaultVal设置的值，如果为0表示采用系统默认的值)才返回，否则就等待
    // 这一步要在前一步骤之后设定
    UInt32 defaultVal = 0;
    CheckStatusReturn(AudioUnitSetProperty(sourceplayer, kAudioUnitProperty_ScheduledFilePrime,
                                    kAudioUnitScope_Global, 0, &defaultVal, sizeof(defaultVal)),
               @"setUpAUFilePlayer AudioUnitSetProperty[kAudioUnitProperty_ScheduledFilePrime] failed");
    
    // 指定从音频文件读取数据的开始时间和时间间隔，此设定会影响AudioUnitRender()函数
    AudioTimeStamp startTime;
    memset (&startTime, 0, sizeof(startTime));
    startTime.mFlags = kAudioTimeStampSampleTimeValid;  // 要想mSampleTime有效，要这样设定
    startTime.mSampleTime = -1; // 表示means next render cycle 否则按照这个指定的数值
    CheckStatusReturn(AudioUnitSetProperty(sourceplayer, kAudioUnitProperty_ScheduleStartTimeStamp,
                                    kAudioUnitScope_Global, 0, &startTime, sizeof(startTime)),
               @"setUpAUFilePlayer AudioUnitSetProperty[kAudioUnitProperty_ScheduleStartTimeStamp]");
    
    
}

- (void)start
{
    OSStatus status = noErr;
    Boolean init = 0;
    AUGraphIsInitialized(_auGraph, &init);
    if (!init) {
        status = AUGraphInitialize(_auGraph);
        if (status != noErr) {
            NSLog(@"AUGraphInitialize error %d",status);
            return;
        }
    }
    
    /** 遇到问题：返回-10862；返回-10860
     *  解决方案：一个AUGraph中必须有一个并且只能有一个I/O Unit，否则会出现 -10862错误;如果没有I/O Unit 则返回-10860错误
     *  I/O Unit有三种：
     *  RemoteIO Unit:连接着设备扬声器和麦克风
     *  Generic output Unit:离线渲染输出 Unit
     *  VOIP Processing Unit:增强版的 RemoteIO Unit
     */
    status = AUGraphStart(_auGraph);
    if (status != noErr) {
        NSLog(@"AUGraphStart error %d",status);
        return;
    }
    
    _offlineRun = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self offlineRenderThread];
    });
    
}

- (void)stop
{
    OSStatus status = noErr;
    status = AUGraphStop(_auGraph);
    _offlineRun = NO;
}

/** 离线渲染的驱动原则：
 *  RemoteIO的驱动原理是：系统硬件(扬声器或者麦克风)会定期采集数据和向客户端要数据渲染，如果有设置回调函数，那么回调函数将被调用
 *  Generic Output不同的是，它需要手动调用AudioUnitRender()函数将AudioUnit中的数据渲染出来
 */
- (void)offlineRenderThread
{
    NSLog(@"离线渲染线程 ==>%@",[NSThread currentThread]);
    
    AudioStreamBasicDescription outputASDB;
    UInt32  outputASDBSize = sizeof(outputASDB);
    CheckStatusReturn(AudioUnitGetProperty(_genericUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &outputASDB,&outputASDBSize),@"get property fail");
    [ADUnitTool printStreamFormat:outputASDB];
    
    if (outputASDB.mBitsPerChannel == 0) {  // 说明没有解析成功
        _offlineRun = NO;
        return;
    }
    
    AudioUnitRenderActionFlags flags = 0;
    AudioTimeStamp inTimeStamp;
    memset(&inTimeStamp, 0, sizeof(inTimeStamp));
    inTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    inTimeStamp.mSampleTime = 0;
    UInt32 framesPerRead = 512*2;
    UInt32 bytesPerFrame = outputASDB.mBytesPerFrame;
    int channelCount = outputASDB.mChannelsPerFrame;
    int bufferListcout = channelCount;
    int bytesPerChannel = outputASDB.mBitsPerChannel/8;
    
    // 不停的向 generic output 要数据;放在外面，避免重复创建和分配内存
    BOOL isPlanner = YES;
    AudioBufferList *bufferlist = (AudioBufferList*)malloc(sizeof(AudioBufferList)+sizeof(AudioBuffer)*(channelCount-1));
    if (outputASDB.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {   // planner 存储方式
        bufferlist->mNumberBuffers = channelCount;
        bufferListcout = channelCount;
        isPlanner = YES;
    } else {    // packet 存储方式
        bufferlist->mNumberBuffers = 1;
        bufferListcout = 1;
        isPlanner = NO;
    }
    for (int i=0; i<bufferListcout; i++) {
        AudioBuffer buffer = {0};
        buffer.mNumberChannels = 1;
        buffer.mDataByteSize = framesPerRead*bytesPerFrame;
        buffer.mData = (void*)calloc(framesPerRead, bytesPerFrame);
        bufferlist->mBuffers[i] = buffer;
    }
    
    UInt32 totalFrames = _totalFrames;
    while (_offlineRun && totalFrames > 0) {
        
        if (totalFrames < framesPerRead) {
            framesPerRead = totalFrames;
        } else {
            totalFrames -= framesPerRead;
        }
        
        // 从generic output unit中将数据渲染出来
        /** 遇到问题：返回-50；
         *  解决方案：在AudioUnit框架中 -50错误代表参数不正确的意思，经过反复检查发现是bufferlist的格式与_genericUnit要输出的数据格式不一致导致，具体
         *  情况为：
         *  _genericUnit为sigendInteger的packet格式，而分配的bufferlist确是sigendInteger planner格式(mNumberBuffers指定为2了)，两边不一致
         *  所以将两者保持一直即可
         *
         *  tips:
         *  调用此函数将向_genericUnit要数据，如果_genericUnit有设置inputCallBack回调，那么回调函数将被调用。
         */
        OSStatus status = AudioUnitRender(_genericUnit,&flags,&inTimeStamp,0,framesPerRead,bufferlist);
        if (status != noErr) {
            NSLog(@"出错了 即将结束写入");
            _offlineRun = NO;
        }
        
        inTimeStamp.mSampleTime += framesPerRead;
        // 将渲染得到的数据保存下来
        if (_extFileWriter) {
            [_extFileWriter writeFrames:framesPerRead toBufferData:bufferlist];
        } else {
            if (isPlanner) {
                // 则需要重新排序一下，将音频数据存储为packet 格式
                int singleChanelLen = bufferlist->mBuffers[0].mDataByteSize;
                size_t totalLen = singleChanelLen * channelCount;
                Byte *buf = (Byte *)malloc(singleChanelLen * channelCount);
                bzero(buf, totalLen);
                for (int j=0; j<singleChanelLen/bytesPerChannel;j++) {
                    for (int i=0; i<channelCount; i++) {
                        Byte *buffer = bufferlist->mBuffers[i].mData;
                        memcpy(buf+j*channelCount*bytesPerChannel+bytesPerChannel*i, buffer+j*bytesPerChannel, bytesPerChannel);
                    }
                }
                [_dataWriteForPCM writeDataBytes:buf len:totalLen];
                
                
                // 释放资源
                free(buf);
                buf = NULL;
            } else {
                AudioBuffer buffer = bufferlist->mBuffers[0];
                UInt32 bufferLenght = bufferlist->mBuffers[0].mDataByteSize;
                [_dataWriteForPCM writeDataBytes:buffer.mData len:bufferLenght];
            }
        }
        
    }
    
    // 释放内存
    for (int i=0; i<bufferListcout; i++) {
        if (bufferlist->mBuffers[i].mData != NULL) {
            free(bufferlist->mBuffers[i].mData);
            bufferlist->mBuffers[i].mData = NULL;
        }
    }
    if (bufferlist != NULL) {
        free(bufferlist);
        bufferlist = NULL;
    }
    
    /** 遇到问题：生成的混音文件无法正常播放
     *  问题原因：通过ExtAudioFileRef生成的封装格式的文件必须要调用ExtAudioFileDispose()函数才会正常生成音频文件属性，由于没有调用导致此问题
     *  解决方案：混音结束后调用ExtAudioFileDispose()即可。
     */
    if (_extFileWriter) {
        [_extFileWriter closeFile];
    }
    NSLog(@"渲染线程结束");
    if (self.completeBlock) {
        self.completeBlock();
    }
}

static OSStatus mixerInputDataCallback(void *inRefCon,
                                       AudioUnitRenderActionFlags *ioActionFlags,
                                       const AudioTimeStamp *inTimeStamp,
                                       UInt32 inBusNumber,
                                       UInt32 inNumberFrames,
                                       AudioBufferList *ioData)
{
    AudioUnitGenericOutput *output = ((__bridge AudioUnitGenericOutput*)inRefCon);
    NSLog(@"输出 时间 %.2f 序号 %d frames %d thread==>%@",inTimeStamp->mSampleTime,inBusNumber,inNumberFrames,[NSThread currentThread]);
    
    return noErr;
}


static OSStatus saveOutputCallback(void *inRefCon,
                                   AudioUnitRenderActionFlags *ioActionFlags,
                                   const AudioTimeStamp *inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList *ioData)
{
    NSLog(@"录音 actionflags %u 时间 %f element %d frames %d 线程==>%@",*ioActionFlags,inTimeStamp->mSampleTime,inBusNumber,inNumberFrames,[NSThread currentThread]);
    
    return noErr;
}

@end
