//
//  BaseUnitPlayer.m
//  media
//
//  Created by Owen on 2019/5/19.
//  Copyright © 2019 Owen. All rights reserved.
//

#import "BaseUnitPlayer.h"

@implementation BaseUnitPlayer
- (id)initWithChannels:(NSInteger)chs sampleRate:(CGFloat)rate format:(ADAudioFormatType)format path:(NSString *)path
{
    if (self = [super init]) {
        self.dSession = [[ADAudioSession alloc] initWithCategary:AVAudioSessionCategoryPlayback channels:chs sampleRate:rate bufferDuration:0.02 fortmatType:format saveType:ADAudioSaveTypePacket];
        
        [self addObservers];
        [self initInputStream:path];
        [self createAudioComponentDesctription];
        [self createAudioUnitByAudioComponentInstanceNew];
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

/**
 *  通过AudioComponentInstanceNew单独创建；
 **/
- (void)createAudioUnitByAudioComponentInstanceNew
{
    // 该方法会根据组件描述去查找对应的组件，若找到则返回，否则返回NULL
    AudioComponent ioCompent = AudioComponentFindNext(NULL, &_ioDes);
    // 根据组件创建对应的 AudioUnit
    OSStatus status = AudioComponentInstanceNew(ioCompent, &_ioUnit);
    if (status != noErr) {
        NSLog(@"AudioComponentInstanceNew fail %d",status);
    }
}

- (void)createAudioComponentDesctription
{
    // 播放音频描述组件
    _ioDes = [ADUnitTool comDesWithType:kAudioUnitType_Output subType:kAudioUnitSubType_RemoteIO fucture:kAudioUnitManufacturer_Apple];
}

- (void)setAudioUnitProperties
{
    // 开启扬声器的播放功能；注：对于扬声器默认是开启的，对于麦克风则默认是关闭的
    uint32_t flag = 1;// 1代表开启，0代表关闭
    OSStatus status = AudioUnitSetProperty(_ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &flag, sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty fail %d",status);
    }
    
    // 设置扬声器的输入音频数据流格式
    AudioFormatFlags flags = self.dSession.formatFlags;
    CGFloat rate = self.dSession.currentSampleRate;
    NSInteger chs = self.dSession.currentChannels;
    NSInteger bytesPerchannel = self.dSession.bytesPerChannel;
    
    AudioStreamBasicDescription odes = [ADUnitTool streamDesWithLinearPCMformat:flags sampleRate:rate channels:chs bytesPerChannel:bytesPerchannel];
    status = AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &odes, sizeof(odes));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty io fail %d",status);
    }
    
    // 设置扬声器的输入接口的回调函数，那么扬声器将通过该回调来拿音频数据
    AURenderCallbackStruct callback;
    callback.inputProc = InputRenderCallback;
    callback.inputProcRefCon = (__bridge void*)self;
    status = AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback));
    if (status != noErr) {
        NSLog(@"AudioUnitSetProperty fail %d",status);
    }
    
    // 初始化AudioUnit
    status = AudioUnitInitialize(_ioUnit);
    if (status != noErr) {
        NSLog(@"AudioUnitInitialize fail %d", status);
    }
}

- (void)play
{
    AudioOutputUnitStart(_ioUnit);
}

- (void)stop
{
    AudioOutputUnitStop(_ioUnit);
    if (inputSteam) {
        [inputSteam close];
        inputSteam = nil;   
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
        if ([self.dSession.aSession usingWiredMicrophone]) {
        } else {
            if (![self.dSession.aSession usingBlueTooth]) {
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

#pragma mark 播放回调
/** AudioBufferList详解
 *  struct AudioBufferList
 *  {
 *      UInt32      mNumberBuffers; // 填写channels个数
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
    BaseUnitPlayer *player = (__bridge id)inRefCon;
    NSLog(@"d1 %p d2 %p",ioData->mBuffers[0].mData,ioData->mBuffers[1].mData);
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        NSInteger result=(UInt32)[player->inputSteam read:ioData->mBuffers[iBuffer].mData maxLength:(NSInteger)ioData->mBuffers[iBuffer].mDataByteSize];
        if (result <=0) {
            [player stop];
            break;
        }
        ioData->mBuffers[iBuffer].mDataByteSize =result;
        NSLog(@"buffer %d out size: %d",iBuffer, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    return noErr;
}
@end
