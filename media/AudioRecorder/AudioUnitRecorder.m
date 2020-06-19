//
//  AudioUnitRecorder.m
//  media
//
//  Created by 飞拍科技 on 2019/6/24.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "AudioUnitRecorder.h"
#define BufferList_cache_size (1024*10*5)

@implementation AudioUnitRecorder
{
    BOOL _isPlanner;
}
- (id)initWithFormatType:(ADAudioFormatType)formatType
                 planner:(BOOL)planner
                channels:(NSInteger)chs
              samplerate:(CGFloat)sampleRate
                    Path:(NSString*)savePath
            saveFileType:(ADAudioFileType)fileType

{
    return [self initWithFormatType:formatType planner:planner channels:chs samplerate:sampleRate Path:savePath recordAndPlay:NO saveFileType:ADAudioFileTypeLPCM];
}

- (id)initWithFormatType:(ADAudioFormatType)formatType
                 planner:(BOOL)planner
                channels:(NSInteger)chs
              samplerate:(CGFloat)sampleRate
                    Path:(NSString*)savePath
           recordAndPlay:(BOOL)yesOrnot
            saveFileType:(ADAudioFileType)fileType
{
    
    return [self initWithFormatType:formatType planner:planner channels:chs samplerate:sampleRate Path:savePath backgroundMusicPath:nil recordAndPlay:yesOrnot saveFileType:fileType];
}

- (id)initWithFormatType:(ADAudioFormatType)formatType
                 planner:(BOOL)planner
                channels:(NSInteger)chs
              samplerate:(CGFloat)sampleRate
                    Path:(NSString*)savePath
     backgroundMusicPath:(NSString*)backgroundPath
           recordAndPlay:(BOOL)yesOrnot
            saveFileType:(ADAudioFileType)fileType
{
    if (self = [super init]) {
    
        _isPlanner = planner;
        _isEnablePlayWhenRecord = yesOrnot;
        _enableMixer = NO;
        
        ADAudioSaveType type = _isPlanner?ADAudioSaveTypePlanner:ADAudioSaveTypePacket;
        AVAudioSessionCategory catory = AVAudioSessionCategoryPlayAndRecord;
        self.audioSession = [[ADAudioSession alloc] initWithCategary:catory channels:chs sampleRate:sampleRate bufferDuration:0.02 fortmatType:formatType saveType:type];
        
        if (savePath) {
            if (fileType == ADAudioFileTypeLPCM) {
                self.dataWriteForPCM = [[AudioDataWriter alloc] initWithPath:savePath];
            } else {
                // 压缩之前的裸音频数据格式
                AudioStreamBasicDescription clientDataASBD = [ADUnitTool streamDesWithLinearPCMformat:self.audioSession.formatFlags sampleRate:sampleRate channels:chs bytesPerChannel:self.audioSession.bytesPerChannel];
                self.dataWriteForNonPCM = [[ADExtAudioFile alloc] initWithWritePath:savePath adsb:clientDataASBD fileTypeId:fileType];
            }
        }
        
        // 来电，连上蓝牙，音箱等打断监听
        [self addInterruptListioner];
        
        // 创建AudioComponentDescription描述符
        [self createAudioUnitComponentDescription];
        
        // 创建AudioUnit
        [self createAudioUnit];
        
        // 设置混音，如果有的话
        [self setBackgroundMusicMixerPath:backgroundPath];
        
        // 设置各个AudioUnit的属性
        [self setupAudioUnitsProperty];
        
        // 将各个AudioUnit单元连接起来
        [self makeAudioUnitsConnectionShipness];
        
        // 初始化缓冲器
        /** 遇到问题：采用传统的方式定义变量:AudioBufferList bufferList;然后尝试对bufferList.mBuffers[1]=NULL，会
         *  奔溃
         *  分析原因：因为AudioBufferList默认是只有1个buffer，mBuffers[1]的属性是未初始化的，相当于是NULL，所以这样直接
         *  访问肯定会奔溃
         *  解决方案：采用如下特殊的C语言方式来为AudioBufferList分配内存，这样mBuffers[1]就不会为NULL了
         */
        /**遇到问题：AudioUnitRender fail ffffffce
         * 解决思路：_ioUnit中指定个流格式类型为Packet的意味着mNumberBuffers必须为1，而这里_bufferList的mNumberBuffers固定为了
         *  含有2个声道，不一致导致出错。两边保持一直
         */
        _bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + (chs - 1) * sizeof(AudioBuffer));
        _bufferList->mNumberBuffers = _isPlanner?(UInt32)chs:1;
        for (NSInteger i=0; i<chs; i++) {
            _bufferList->mBuffers[i].mData = malloc(BufferList_cache_size);
            _bufferList->mBuffers[i].mDataByteSize = BufferList_cache_size;
            memset(_bufferList->mBuffers[i].mData,0,BufferList_cache_size);
        }
    }
    
    return self;
}

/** 音轨混合的原理：
 *  空气中声波的叠加等价于量化的语音信号的叠加
 *  多路音轨混合的前提：
 *  需要叠加的音轨具有相同的采样频率，采样精度和采样通道，如果不相同，则需要先让他们相同
 *  1、不同采样频率需要算法进行重新采样处理
 *  2、不同采样精度则通过算法将精度保持一样，精度向上扩展和精度向下截取
 *  3、不同通道数也是和精度类似处理方式
 *  音轨混合算法：
 *  比如线性叠加平均、自适应混音、多通道混音等等
 *  线性叠加平均：原理就是把不同音轨的各个通道值(对应的每个声道的值)叠加之后取平均值，优点不会有噪音，缺点是如果
 *  某一路或几路音量特别小那么导致整个混音结果的音量变小
 *  伪代码 音轨1：a11b11c11a12b12c12a13b13c13
 *        音轨2：a21b21c21a22b22c22a23b23c23
 *        混音:  (a11+a21)/2(b11+b21)/2(c13+c23)/2
 *  自适应混音：根据每路音轨所占的比例权重进行叠加，具体算法有很多种，这里不详解
 *  多通道混音：将每路音轨分别放到各个声道上，就好比如果有两路音轨，则一路音轨放到左声道，一路音轨放到右声道。那如果
 *  要混合的音轨数大于设备的通道数呢？
 *  对于ios平台，提供了Mixer混音器，它提供了内置的混音算法供我们使用，我们只需要指定要混合的音轨数，混合后音轨音量大
 *  小，确定每路音轨的采样率一致等等配置参数即可。
 */
- (void)setBackgroundMusicMixerPath:(NSString *)path
{
    if (path == nil) {
        NSLog(@"混音文件路径为空");
        return;
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSLog(@"混音文件不存在");
        return;
    }
    
    _enableMixer = YES;
    _mixerPath = path;
    
    /** 1、配置从文件中读取的音频数据最终解码后输出给app的数据格式，AudioUnitFileRex内部会进行解码，和格式转化
     *  2、混音要保证各个音轨的采样率，采样精度，声道数一致，这里不考虑这么复杂的情况，录制的音频格式保持与音频文件中音频格式一致
     *  3、如果两者不一致，则两路音轨数据传入混音器之前要进行重采样
     */
    /** 网络序就是大端序，Native就是主机序(跟硬件平台有关，要么大端序要么小端序)，一般一个类型的平台主机序是固定的
     *  比如ios平台Native就是小端序
     *  对于_mixerUnit，它的kAudioUnitScope_OutScope是一个和_clientFormat32float固定格式的ABSD，不需要
     *  额外设置
     */
    UInt32 bytesPerSample = 4;  // 要与下面mFormatFlags 对应
    AudioStreamBasicDescription absd;
    absd.mFormatID          = kAudioFormatLinearPCM;
    absd.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    absd.mBytesPerPacket    = bytesPerSample;
    absd.mFramesPerPacket   = 1;
    absd.mBytesPerFrame     = 4;
    absd.mChannelsPerFrame  = 2;
    absd.mBitsPerChannel    = 8 * bytesPerSample;
    absd.mSampleRate        = 0;
    
    self.dataReader = [[ADExtAudioFile alloc] initWithReadPath:path adsb:absd canrepeat:NO];
    _mixerStreamDesForInput = self.dataReader.clientABSD;
}

- (void)startRecord
{
    // 删除之前文件
    [self.dataWriteForPCM deletePath];
    
    OSStatus status = noErr;

    status = AUGraphInitialize(_augraph);
    if (status != noErr) {
        NSLog(@"AUGraphInitialize fail %d",status);
    }
    
    status = AUGraphStart(_augraph);
    if (status != noErr) {
        NSLog(@"AUGraphStart fail %d",status);
    }
}

- (void)stopRecord
{
    OSStatus status = noErr;
    status = AUGraphStop(_augraph);
    if (status != noErr) {
        NSLog(@"AUGraphStop fail %d",status);
    }
    
    // 必须要有，否则生成的音频文件无法播放
    if (self.dataWriteForNonPCM) {
        [self.dataWriteForNonPCM closeFile];
        self.dataWriteForNonPCM = nil;
    }
}

- (void)dealloc
{
    if (_bufferList != NULL) {
        for (int i=0; i<_bufferList->mNumberBuffers; i++) {
            if (_bufferList->mBuffers[i].mData != NULL) {
                free(_bufferList->mBuffers[i].mData);
                _bufferList->mBuffers[i].mData = NULL;
            }
        }
        free(_bufferList);
        _bufferList = NULL;
    }
}

- (void)addInterruptListioner
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

- (void)createAudioUnitComponentDescription
{
    // 创建RemoteIO
    _iodes = [ADUnitTool comDesWithType:kAudioUnitType_Output subType:kAudioUnitSubType_VoiceProcessingIO fucture:kAudioUnitManufacturer_Apple];
    // 创建格式转换器；使用混音功能的时候才用到
    _convertdes = [ADUnitTool comDesWithType:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_AUConverter fucture:kAudioUnitManufacturer_Apple];
    // 创建混音器；使用混音功能的时候才用到
    _mixerDes = [ADUnitTool comDesWithType:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer fucture:kAudioUnitManufacturer_Apple];
}

/** 基于AUGraph的AudioUnit，他们按照如下的驱动规则运行。
 *  麦克风 ->其它组件(mixer Unit/Convert Unit等其它组件) ... 输出Unit(扬声器或者Generic Output IO)
 *  和下面AUGraphAddNode()调用顺序无关
 *  remoteIO和Generic Output IO不能在同一个AUGGraph中
 */
- (void)createAudioUnit
{
    OSStatus status = noErr;
    // 1、创建AUGraph
    status = NewAUGraph(&_augraph);
    if (status != noErr) {
        NSLog(@"NewAUGraph fail %d",status);
    }
    CAShow(_augraph);
    
    // 2、根据指定的组件描述符(AudioComponentDescription)创建AUNode,并添加到AUGraph中
    status = AUGraphAddNode(_augraph, &_iodes, &_ioNode);
    if (status != noErr) {
        NSLog(@"AUGraphAddNode _iodes fail %d",status);
    }
    status = AUGraphAddNode(_augraph, &_mixerDes, &_mixerNode);
    if (status != noErr) {
        NSLog(@"AUGraphAddNode _mixerDes fail %d",status);
    }
    status = AUGraphAddNode(_augraph, &_convertdes, &_convertNode);
    if (status != noErr) {
        NSLog(@"AUGraphAddNode _convertdes fail %d",status);
    }
    
    // 3、打开AUGraph，打开之后才能获取AudioUnit
    status = AUGraphOpen(_augraph);
    if (status != noErr) {
        NSLog(@"AUGraphStart fail %d",status);
    }
    
    // 4、根据AUNode 获取对应AudioUnit；这一步一定要在初始化AUGraph之后;第三个参数传NULL即可
    status = AUGraphNodeInfo(_augraph, _mixerNode, NULL, &_mixerUnit);
    if (status != noErr) {
        NSLog(@"AUGraphNodeInfo _mixerUnit fail %d",status);
    }
    status = AUGraphNodeInfo(_augraph, _ioNode, NULL, &_ioUnit);
    if (status != noErr) {
        NSLog(@"AUGraphNodeInfo _ioUnit fail %d",status);
    }
    status = AUGraphNodeInfo(_augraph, _convertNode, NULL, &_convertUnit);
    if (status != noErr) {
        NSLog(@"AUGraphNodeInfo _convertNode fail %d",status);
    }
}

- (void)setupAudioUnitsProperty
{
    // 1、开启麦克风录制功能
    UInt32 flag = 1;
    OSStatus status = noErr;
    // 对于麦克风：第三个参数为kAudioUnitScope_Input， 第四个参数为1
    // 对于扬声器：第三个参数为kAudioUnitScope_Output，第四个参数为0
    // 其它参数都一样;扬声器默认是打开的
    status = AudioUnitSetProperty(_ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flag, sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty kAudioUnitScope_Output fail %d",status);
    }
    
    // 2、设置麦克风的输出端参数属性，那么麦克风将按照指定的采样率，格式，存储方式来采集数据然后输出
    AudioFormatFlags flags = self.audioSession.formatFlags;
    NSInteger _bytesPerchannel = self.audioSession.bytesPerChannel;
    
    // 录制音频的输出的数据格式
    CGFloat rate = self.audioSession.currentSampleRate;
    NSInteger chs = self.audioSession.currentChannels;
    AudioStreamBasicDescription recordASDB = [ADUnitTool streamDesWithLinearPCMformat:flags sampleRate:rate channels:chs bytesPerChannel:_bytesPerchannel];
    
    // 设置录制音频的输出数据格式
    status = AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &recordASDB, sizeof(recordASDB));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty _ioUnit kAudioUnitScope_Output fail %d",status);
    }
    
    if (_isEnablePlayWhenRecord) {
        status = AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &recordASDB, sizeof(recordASDB));
        if (status != noErr) {
            NSLog(@"AudioUnitSetProperty _ioUnit kAudioUnitScope_Input 0 fail %d",status);
        }
    }
    
    if (_enableMixer) {
        _mixerStreamDesForOutput = [ADUnitTool streamDesWithLinearPCMformat:flags sampleRate:rate channels:chs bytesPerChannel:_bytesPerchannel];
        
        /** 指定混音器的输入音轨数目，这里是混合的音频文件和录音的音频数据，所以是两个
         *  备注：混音器可以有多个输入，但是只有一个输出，AudioUnitElement值为0
         */
        UInt32 mixerInputcount = _isEnablePlayWhenRecord?2:1;
        CheckStatusReturn(AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &mixerInputcount, sizeof(mixerInputcount)),@"kAudioUnitProperty_ElementCount");
        
        // 指定混音器的采样率
        status = AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0, &rate, sizeof(rate));
        
        // 设置AudioUnitRender()函数在处理输入数据时，最大的输入吞吐量
        UInt32 maximumFramesPerSlice = 4096;
        AudioUnitSetProperty (
                              _ioUnit,
                              kAudioUnitProperty_MaximumFramesPerSlice,
                              kAudioUnitScope_Global,
                              0,
                              &maximumFramesPerSlice,
                              sizeof (maximumFramesPerSlice)
                              );
        
        
        /** 讲一下这里面的逻辑
         *  录制的音频作为一路音频输入到混音器，从文件读取的音频作为另一路音频输入到混音器，它们要保持相同的采样率，采样格式，声道数。这里以录制的
         *  音频输出的数据格式作为混音器数据的输入格式，所以格式转换器用于转换从文件读取的音频数据
         */
        status = AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,&recordASDB, sizeof(recordASDB));
    }
    
}

/** kAudioOutputUnitProperty_SetInputCallback、kAudioUnitProperty_SetRenderCallback和AUGraphSetNodeInputCallback()区别
 *  kAudioOutputUnitProperty_SetInputCallback：
 *  用于系统设备(比如麦克风)向app输出数据的回调，app在该回调内调用AudioUnitRender()函数可以将麦克风内部数据渲染为指定的asdb类型的音频数据，
 *  所以该回调只可以麦克风等能想app提供数据的Unit使用
 *  kAudioUnitProperty_SetRenderCallback：
 *  用于由APP向任何Audio Unit的 input bus element 提供数据。比如向扬声器的input bus(0)，向mixer的各个input bus等等。app在该回调内
 *  向AudioBufferList提供音频数据，要注意的是该回调被执行的前提是该Unit要连接到输出Unit(扬声器或者generic output unit)上
 *  AUGraphSetNodeInputCallback():
 *  它与kAudioUnitProperty_SetRenderCallback功能一样
 */
- (void)makeAudioUnitsConnectionShipness
{
    if (!_enableMixer) {
        
        if (_isEnablePlayWhenRecord) {      // 麦克风的输出作为扬声器的输入 即开启了耳返效果
            AUGraphConnectNodeInput(_augraph, _ioNode, 1, _ioNode, 0);
        }
        
        if (self.dataWriteForNonPCM||self.dataWriteForPCM) {
            AURenderCallbackStruct callback;
            callback.inputProc = saveOutputCallback;
            callback.inputProcRefCon = (__bridge void*)self;
            /** tips:前面即使将麦克风的输出作为扬声器的输入，这里也可以再为麦克风的输出设置回调，他们是互不干扰的。但是需要在回调里面手动调用
             *  AudioUnitRender()函数将数据渲染出来
             */
            AudioUnitSetProperty(_ioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Output, 1, &callback, sizeof(callback));
        }
        return;
    } else {        // 开启了混音
        OSStatus status = noErr;
        AUGraphConnectNodeInput(_augraph, _mixerNode, 0, _ioNode, 0);
        
        int mixerCount = _isEnablePlayWhenRecord?2:1;
        // 为混音器配置输入
        for (int i=0; i<mixerCount; i++) {
            AURenderCallbackStruct callback;
            callback.inputProc = mixerInputDataCallback;
            callback.inputProcRefCon = (__bridge void*)self;
            status = AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, i, &callback, sizeof(callback));
            if (status != noErr) {
                NSLog(@"AudioUnitSetProperty kAudioUnitProperty_SetRenderCallback %d",status);
            }
            status = AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &_mixerStreamDesForInput, sizeof(_mixerStreamDesForInput));
            if (status != noErr) {
                NSLog(@"AudioUnitSetProperty kAudioUnitProperty_StreamFormat %d",status);
            }
        }
        
        if (_isEnablePlayWhenRecord) {
            AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &_mixerStreamDesForInput, sizeof(_mixerStreamDesForInput));
            /** 遇到问题：混音器的输出格式 无法设置？一直返回-108868，但是也不影响结果。
             *  分析原因：想一下也正确，因为混音器的输出格式肯定和输入格式一样
             *  解决方案：去掉混音器输出格式设置，对结果不影响
             */
//            status = AudioUnitSetProperty(_mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &_mixerStreamDesForOutput, sizeof(_mixerStreamDesForOutput));
        }
        
        if ((self.dataWriteForNonPCM||self.dataWriteForPCM)) {
            AURenderCallbackStruct callback;
            callback.inputProc = saveOutputCallback;
            callback.inputProcRefCon = (__bridge void*)self;
            status = AudioUnitSetProperty(_ioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Output, 1, &callback, sizeof(callback));
            if (status != noErr) {
                NSLog(@"AudioUnitSetProperty kAudioOutputUnitProperty_SetInputCallback %d",status);
            }
        }
    }
}

/** 作为音频录制输出的回调
 *  1、ioActionFlags 表示目前render operation的阶段
 *  2、inTimeStamp   表示渲染操作的时间 一般12ms调用一次
 *  3、inBusNumber 对应RemoteIO的 BusNumber
 *  4、inNumberFrames 每一次渲染的采样数
 *  5、ioData为NULL
 */
static OSStatus saveOutputCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData)
{
    AudioUnitRecorder *player = (__bridge AudioUnitRecorder*)inRefCon;
    UInt32 chs = (UInt32)player.audioSession.currentChannels;
    BOOL isPlanner = player->_isPlanner;
    NSInteger bytesPerChannel = player.audioSession.bytesPerChannel;
    static Float64 lastTime = 0;
    lastTime = inTimeStamp->mSampleTime;
    
    // 如果作为音频录制的回调，ioData为NULL
//    NSLog(@"d1 %p d2 %p",ioData->mBuffers[0].mData,ioData->mBuffers[1].mData);
    AudioBufferList *bufferList = player->_bufferList;


    OSStatus status = noErr;
    // 该函数的作用就是将麦克风采集的音频数据根据前面配置的RemoteIO输出数据格式渲染出来，然后放到
    // bufferList缓冲中；那么这里将是PCM格式的原始音频帧
    status = AudioUnitRender(player->_ioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, bufferList);
    /** 遇到问题：AudioUnitRender 返回-50
     */
    NSLog(@"status %d 录音 actionflags %u 时间 %f element %d frames %d channel %d planer %d 线程==>%@",status,*ioActionFlags,inTimeStamp->mSampleTime-lastTime,inBusNumber,inNumberFrames,chs,isPlanner,[NSThread currentThread]);
    if (status != noErr) {
        NSLog(@"AudioUnitRender fail %d",status);
        return status;
    }
    if (bufferList->mBuffers[0].mData == NULL) {
        return noErr;
    }
    
    if (player.dataWriteForPCM) {
        /** 遇到问题：如果采集的存储格式为Planner类型，播放不正常
         *  解决方案：ios采集的音频为小端字节序，采集格式为32位，只需要将bufferList中mBuffers对应的数据重新
         *  组合成 左声道右声道....左声道右声道顺序的存储格式即可
         */
        if (isPlanner) {
            // 则需要重新排序一下，将音频数据存储为packet 格式
            int singleChanelLen = bufferList->mBuffers[0].mDataByteSize;
            size_t totalLen = singleChanelLen * chs;
            Byte *buf = (Byte *)malloc(singleChanelLen * chs);
            bzero(buf, totalLen);
            for (int j=0; j<singleChanelLen/bytesPerChannel;j++) {
                for (int i=0; i<chs; i++) {
                    Byte *buffer = bufferList->mBuffers[i].mData;
                    memcpy(buf+j*chs*bytesPerChannel+bytesPerChannel*i, buffer+j*bytesPerChannel, bytesPerChannel);
                }
            }
            if (player.dataWriteForPCM) {
                [player.dataWriteForPCM writeDataBytes:buf len:totalLen];
            }
            
            
            // 释放资源
            free(buf);
            buf = NULL;
        } else {
            AudioBuffer buffer = bufferList->mBuffers[0];
            UInt32 bufferLenght = bufferList->mBuffers[0].mDataByteSize;
            if (player.dataWriteForPCM) {
                [player.dataWriteForPCM writeDataBytes:buffer.mData len:bufferLenght];
            }
        }
    } else if(player.dataWriteForNonPCM){
        // 内部将实现压缩并且封装格式
        [player.dataWriteForNonPCM writeFrames:inNumberFrames toBufferData:bufferList];
    }
    
    
    return status;
}

static OSStatus mixerInputDataCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData)
{
    AudioUnitRecorder *recorder = ((__bridge AudioUnitRecorder*)inRefCon);
    NSLog(@"输出 时间 %.2f 序号 %d frames %d",inTimeStamp->mSampleTime,inBusNumber,inNumberFrames);
    OSStatus status = noErr;
    if (recorder->_isEnablePlayWhenRecord) {    // 开启了耳返
        if (inBusNumber == 0) {     // 代表录音
            // 将录音的数据填充进来
            status = AudioUnitRender(recorder->_ioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
        } else if (inBusNumber == 1){   // 代表音频文件
            // 从音频文件中读取数据并填充进来
            status = [recorder->_dataReader readFrames:&inNumberFrames toBufferData:ioData];
        }
    } else {
        status = [recorder->_dataReader readFrames:&inNumberFrames toBufferData:ioData];
    }
    return status;
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
        // 检测是否能用耳机，如果能用，则切换为耳机模式
        if ([self.audioSession.aSession usingWiredMicrophone]) {
        } else {
            // 检测是否能用蓝牙，如果能用，则用蓝牙进行连接
            if (![self.audioSession.aSession usingBlueTooth]) {
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
            
            break;
        case AVAudioSessionInterruptionTypeEnded:
            
            break;
        default:
            break;
    }
}
@end
