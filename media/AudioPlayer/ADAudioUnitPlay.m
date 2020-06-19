//
//  ADAudioUnitPlay.m
//  media
//
//  Created by Owen on 2019/5/14.
//  Copyright © 2019 Owen. All rights reserved.
//

#import "ADAudioUnitPlay.h"

@implementation ADAudioUnitPlay
{
    NSString *_audioPath;
}
/** 有关结构体
 *  OSStatus;typedef SInt32 OSStatus;noErr;定义在/usr/include/MacTypes.h中
 *  以下结构体都在AudioToolbox下：
 *  AudioUnit;它是一个单元，typedef AudioComponentInstance AudioUnit;
 *  AudioComponentDescription;包括Type，subType，Manufacture(厂商)等等，是构成AudioUnit必不可少的结构体
 *  AUGraph;它是一个桥接器，用来获取AudioUnit;typedef struct OpaqueAUGraph *AUGraph;
 *  AUNode;对于AudioUnit的封装，结合AUGraph获取AudioUnit
 */
-(id)initWithChannels:(NSInteger)chs
           sampleRate:(CGFloat)rate
           formatType:(ADAudioFormatType)formatType
              planner:(BOOL)planner
                 path:(NSString*)path
{
    if (self = [super init]) {
        _audioPath = path;
        _playNonPCM = NO;
        
        // 1、配置音频会话 AVAudioSession，播放和录制音频都需要该会话
        self.aSession = [[ADAudioSession alloc] initWithCategary:AVAudioSessionCategoryPlayback channels:chs sampleRate:rate bufferDuration:0.02 fortmatType:formatType saveType:ADAudioSaveTypePacket];
        // 2、配置打断事件的通知监听，比如用户播放音频/录制音频时插上耳机，h手机连上了蓝牙，突然来电
        // 等等事件，对这些事件如何处理;一般播放和录制音频都需要该处理该监听通知
        [self addObservers];
        // 3、配置播放文件输入流
        [self initInputStream:path];
        // 4、创建播放音频的描述组件，它描述了AudioUnit的类型和属性，每一种AudioUnit代表了一个功能，
        // 比如用于播放音频的kAudioUnitType_Output
        [self createAudioComponentDesctription];
        // 5、实例化AudioUnit
        [self createAudioUnitByAugraph];
        // 6、配置AudioUnit属性，同时构建Augraph工作流程图，将各个AudioUnit连接起来，构成一个完整的工作流。
        [self setAudioUnitProperties];
        
    }
    return self;
}

-(id)initWithAudioFilePath:(NSString*)path fileType:(ADAudioFileType)fileType
{
    if (self = [super init]) {
        _audioPath = path;
        _playNonPCM = YES;
        
        // 从音频文件中读取数据解码后的音频数据格式;经过测试，发现只支持AudioFilePlayer解码后输出的数据格式只支持
        // kAudioFormatFlagIsFloat|kAudioFormatFlagIsNonInterleaved;
        AudioFormatFlags flags = kAudioFormatFlagIsFloat|kAudioFormatFlagIsNonInterleaved;
        AudioStreamBasicDescription inputASDB = [ADUnitTool streamDesWithLinearPCMformat:flags sampleRate:44100 channels:2 bytesPerChannel:4];
        _readFile = [[ADExtAudioFile alloc] initWithReadPath:path adsb:inputASDB canrepeat:NO];
        
        AudioStreamBasicDescription clientASBD = _readFile.clientABSD;
        // todo:zsz 位置1
        self.aSession = [[ADAudioSession alloc] initWithCategary:AVAudioSessionCategoryPlayback channels:clientASBD.mChannelsPerFrame sampleRate:clientASBD.mSampleRate bufferDuration:0.02 fortmatType:ADAudioFormatType32Float saveType:ADAudioSaveTypePlanner];
        
        [self addObservers];
        
        [self createAudioComponentDesctription];
        
        [self createAudioUnitByAugraph];
        
        [self setAudioUnitProperties];
        
        
        
    
    }
    return self;
}

- (void)addObservers
{
    // 添加路由改变时的通知;比如用户插上了耳机，则remoteIO的element0对应的输出硬件由扬声器变为了耳机;策略就是 如果用户连上了蓝牙，则屏蔽手机内置的扬声器
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    // 播放过程中收到了被打断的通知处理;比如突然来电，等等。
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onNotificationAudioInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
}

- (void)createAudioComponentDesctription
{
    // 播放音频描述组件
    _ioDes = [ADUnitTool comDesWithType:kAudioUnitType_Output subType:kAudioUnitSubType_RemoteIO fucture:kAudioUnitManufacturer_Apple];
    // 格式转换器组件
    _cvtDes = [ADUnitTool comDesWithType:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_AUConverter fucture:kAudioUnitManufacturer_Apple];
}

- (void)initInputStream:(NSString*)path
{
    // open pcm stream
    NSURL *url = [NSURL fileURLWithPath:path];
    inputSteam = [NSInputStream inputStreamWithURL:url];
    if (!inputSteam) {
        NSLog(@"打开文件失败 %@", url);
    }
    else {
        [inputSteam open];
    }
}

/** 创建 AudioUnit
 *  和通过AUGraph创建；
 */
- (void)createAudioUnitByAugraph
{
    OSStatus status = noErr;
    //1、创建AUGraph
    status = NewAUGraph(&_aGraph);
    if (status != noErr) {
        NSLog(@"create AUGraph fail %d",status);
    }
    
    //2.2 将指定的组件描述创建AUNode并添加到AUGraph中
    status = AUGraphAddNode(_aGraph, &_ioDes, &_ioNode);
    if (status != noErr) {
        NSLog(@"AUGraphAddNode fail _ioDes %d",status);
    }
    status = AUGraphAddNode(_aGraph, &_cvtDes, &_cvtNode);
    if (status != noErr) {
        NSLog(@"AUGraphAddNode fail _cvtDes %d",status);
    }
    
    // 3、打开AUGraph(即初始化了AUGraph)
    status = AUGraphOpen(_aGraph);
    if (status != noErr) {
        NSLog(@"AUGraphOpen fail %d",status);
    }
    
    // 4、打开了AUGraph之后才能获取指定的AudioUnit
    status = AUGraphNodeInfo(_aGraph, _ioNode, NULL, &_ioUnit);
    if (status != noErr) {
        NSLog(@"AUGraphNodeInfo fail %d",status);
    }
    status = AUGraphNodeInfo(_aGraph, _cvtNode, NULL, &_cvtUnit);
    if (status != noErr) {
        NSLog(@"AUGraphNodeInfo fail %d",status);
    }
}

/** 设置AudioUnit属性
 *  1、通过AudioUnitSetProperty(AudioUnit inUnit,
 *              AudioUnitPropertyID      inID,
 *              AudioUnitScope           inScope,
 *              AudioUnitElement         inElement,
 *          const void * __nullable      inData,
 *             UInt32                    inDataSize
 *              )
 *  2、对于开启和关闭麦克风和扬声器的功能，inID取值为kAudioOutputUnitProperty_EnableIO
 *  3、关于remoteIO的element，扬声器对应的AudioUnitElement值为0，麦克风对应的AudioUnitElement值为1
 *  4、每一个AudioUnit可以有至少一个输入(kAudioUnitScope_Input)和输出(kAudioUnitScope_Output)，对于remoteIO的element,扬
 *  声器对应的AudioUnitElement值为0，麦克风对应的AudioUnitElement值为1；对于AUConverter类型格式转换器，它的AudioUnitElement值
 *  总为0；对于Mixer类型的混音器，它只能有一个输出
 *  4、对于麦克风，它的kAudioUnitScope_Input连接的是系统音频采集硬件，用于采集声音；kAudioUnitScope_Output连接的则是应用端，用于将采集的
 *  音频按照指定的格式输出给应用端；所以这下可以明白为什么开启麦克风硬件的inScope参数是kAudioUnitScope_Input了
 *  5、对于扬声器，它的kAudioUnitScope_Input连接的是应用端，用于接收来自应用端的指定格式的音频数据；kAudioUnitScope_Output连接的则是系统
 *  音频播放硬件，用于播放声音；所以这下可以明白为什么开启扬声器硬件的inScope参数是kAudioUnitScope_Output了
 */
- (void)setAudioUnitProperties
{
    // 开启扬声器的播放功能；注：对于扬声器默认是开启的，对于麦克风则默认是关闭的
    uint32_t flag = 1;// 1代表开启，0代表关闭
    OSStatus status = AudioUnitSetProperty(_ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &flag, sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty fail %d",status);
    }
    
    CGFloat rate = self.aSession.currentSampleRate;
    NSInteger chs = self.aSession.currentChannels;
    //输入给扬声器的音频数据格式
    /** 遇到问题：AUGraphInitialize fail -10868
     *  解决方案：创建AudioStreamBasicDescription对象时，mFormatFlags对应的数据格式一定要与mBitsPerChannel一致
     */
    AudioStreamBasicDescription odes = [ADUnitTool streamDesWithLinearPCMformat:kAudioFormatFlagIsFloat|kAudioFormatFlagIsNonInterleaved sampleRate:rate channels:chs bytesPerChannel:4];
    
    // PCM文件的音频的数据格式
    AudioFormatFlags flags = self.aSession.formatFlags;
    NSInteger _bytesPerChannel = self.aSession.bytesPerChannel;
    // todo:zsz 位置2
    AudioStreamBasicDescription cvtInDes = [ADUnitTool streamDesWithLinearPCMformat:flags sampleRate:rate channels:chs bytesPerChannel:_bytesPerChannel];
    
    // 设置扬声器的输入音频数据格式
    status = AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &odes, sizeof(odes));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty io fail %d",status);
    }
    
    // 设置格式转换器的输入输出音频数据格式;对于格式转换器AudioUnit 他的AudioUnitElement只有一个 element0
    status = AudioUnitSetProperty(_cvtUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &cvtInDes, sizeof(cvtInDes));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty convert in fail %d",status);
    }
    status = AudioUnitSetProperty(_cvtUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &odes, sizeof(odes));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty convert ou fail %d",status);
    }
    
    /** 构建连接
     *  只有构建连接之后才有一个完整的数据驱动链。如下将构成链条如下：
     *  _cvtUnit通过回调向文件要数据，得到数据后进行格式转换，将输出作为输入数据输送给_ioUnit，然后
     *  _ioUnit播放数据
     */
    status = AUGraphConnectNodeInput(_aGraph, _cvtNode, 0, _ioNode, 0);
    if (status != noErr) {
        NSLog(@"AUGraphConnectNodeInput fail %d",status);
    }
    AURenderCallbackStruct callback;
    callback.inputProc = InputRenderCallback;
    callback.inputProcRefCon = (__bridge void*)self;
//    status = AudioUnitSetProperty(_cvtUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback));
    // 换成下面的函数与上面效果一样
    status = AUGraphSetNodeInputCallback(_aGraph, _cvtNode, 0, &callback);
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty fail %d",status);
    }
}

- (void)play
{
    OSStatus stauts;
    CAShow(_aGraph);
    
    // 7、初始化AUGraph,初始化之后才能正常启动播放
    stauts = AUGraphInitialize(_aGraph);
    if (stauts != noErr) {
        NSLog(@"AUGraphInitialize fail %d",stauts);
    }
    stauts = AUGraphStart(_aGraph);
    if (stauts != noErr) {
        NSLog(@"AUGraphStart fail %d",stauts);
    }
    
    if (inputSteam == nil) {
        [self initInputStream:_audioPath];
    }
}

- (void)stop
{
    OSStatus status;
    status = AUGraphStop(_aGraph);
    if (status != noErr) {
        NSLog(@"AUGraphStop fail %d",status);
    }
    
    if (inputSteam) {
        [inputSteam close];
        inputSteam = nil;
    }
    
    if (_readFile) {
        [_readFile closeFile];
        _readFile = nil;
    }
}

- (void)destroyAudioUnit
{
    if (_aGraph) {
        AUGraphStop(_aGraph);
        AUGraphUninitialize(_aGraph);
        AUGraphClose(_aGraph);
        AUGraphRemoveNode(_aGraph, _ioNode);
        DisposeAUGraph(_aGraph);
        _ioUnit = NULL;
        _ioNode = 0;
        _aGraph = NULL;
    } else {
        AudioOutputUnitStop(_ioUnit);
    }
    
}

#pragma mark 播放声音过程中收到了路由改变通知处理
- (void)onNotificationAudioRouteChange:(NSNotification *)sender
{
    [self adjustOnRouteChange];
}

- (void)adjustOnRouteChange
{
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    if (currentRoute) {
        if ([self.aSession.aSession usingWiredMicrophone]) {
        } else {
            if (![self.aSession.aSession usingBlueTooth]) {
                [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
            }
        }
    }
}

#pragma mark 播放声音过程中收到了路由改变通知处理
- (void)onNotificationAudioInterrupted:(NSNotification *)sender {
    AVAudioSessionInterruptionType interruptionType = [[[sender userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            [self stop];
            break;
        case AVAudioSessionInterruptionTypeEnded:
            [self play];
            break;
        default:
            break;
    }
}

/** AudioBufferList详解
 *  struct AudioBufferList
 *  {
 *      UInt32      mNumberBuffers;
 *      AudioBuffer mBuffers[1]; // 这里的定义等价于 AudioBuffer *mBuffers,所以它的元素个数是不固定的,元素个数由mNumberBuffers决定;
 *      对于packet数据,各个声道数据依次存储在mBuffers[0]中,对于planner格式,每个声道数据分别存储在mBuffers[0],...,mBuffers[i]中
 *      对于packet数据,AudioBuffer中mNumberChannels数目等于channels数目，对于planner则始终等于1
 *      ......
 *  };
 *  typedef struct AudioBufferList  AudioBufferList;
 */
// 大概每10ms 扬声器会向app要一次数据
static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData)
{
    ADAudioUnitPlay *player = (__bridge id)inRefCon;
    if (player->inputSteam && !player->_playNonPCM) {
        OSStatus result= (OSStatus)[player->inputSteam read:ioData->mBuffers[0].mData maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
        NSLog(@"d1 %p size %d",ioData->mBuffers[0].mData,result);
        if (result <0) {
            [player stop];
            return kCGErrorNoneAvailable;
        }
        ioData->mBuffers[0].mDataByteSize = (UInt32)result;
    } else if(player->_readFile) {
        /** 遇到问题：返回 -50 错误1111: EXCEPTION (-50): "wrong number of buffers"
         *  分析原因：因为前面// todo:zsz 位置1的存储格式之前给的packet，而// todo:zsz 位置2输入的音频格式给的是planner，两边不一致
         *  解决方案：两边保持一直即可
         */
        OSStatus result= (OSStatus)[player->_readFile readFrames:&inNumberFrames toBufferData:ioData];
        if (result <0 || inNumberFrames == 0) {
            [player stop];
            return kCGErrorNoneAvailable;
        }
    }
    
    return noErr;
}
@end
