//
//  AudioEnDecodeViewController.m
//  media
//
//  Created by 飞拍科技 on 2019/7/18.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "AudioEnDecodeViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AudioHardCodec.h"
#import "AudioDataWriter.h"
#import "SFVideoEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface AudioEnDecodeViewController ()<AVCaptureAudioDataOutputSampleBufferDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>
{
    EBDropdownListView *_dropdownListView;
    dispatch_queue_t    _audioQueue;
    AudioHardCodec      *_encoder;
    AudioHardCodec      *_decoder;
    AudioDataWriter     *_dataWriter;
}
// 编解码按钮
@property (strong, nonatomic) UIButton *beginButton;

/** @AVCaptureSession对象；
 *  位于AVFoundation下的AVCaptureSession.h中，用于管理麦克风采集和摄像头采集的连接器
 *  @AVCaptureDeviceInput；
 *  是AVCaptureInput(抽闲类)的子类，代表了具体的输入设备，它由AVCaptureDevice生成，要添加到AVCaptureSession中进行管理
 *  @AVCaptureAudioDataOutput；
 *  是AVCaptureOutput(抽闲类)的子类，代表了具体的输出设备，它由AVCaptureDevice生成，要添加到AVCaptureSession中进行管理
 */
@property (nonatomic , strong) AVCaptureSession *captureSession;
// 音频输入设备对象
@property (nonatomic , strong) AVCaptureDeviceInput *audioCaptureInput;
// 音频设备输出对象，音频数据由此对象提供
@property (nonatomic , strong) AVCaptureAudioDataOutput *audioCaptureOutput;
// 视频输入设备对象
@property (nonatomic , strong) AVCaptureDeviceInput *videoCaptureInput;
// 视频设备输出对象，音频数据由此对象提供
@property (nonatomic , strong) AVCaptureVideoDataOutput *videoCaptureOutput;

@property (nonatomic , strong) AudioHardCodec   *audioEncoder;  //音频编码器
@property (nonatomic , strong) SFVideoEncoder       *videoEncoder;
@end

@implementation AudioEnDecodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _audioQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.beginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.beginButton.frame = CGRectMake(150, 200, 100, 50);
    [self.beginButton setTitle:@"开始" forState:UIControlStateNormal];
    [self.view addSubview:self.beginButton];
    [self.beginButton addTarget:self action:@selector(onTapBtn:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)onTapBtn:(UIButton*)btn
{
    if (self.captureSession) {
        [self.captureSession stopRunning];
        self.captureSession = nil;
        [self.beginButton setTitle:@"开始" forState:UIControlStateNormal];
        return;
    }
    
    [self.beginButton setTitle:@"停止" forState:UIControlStateNormal];
    
    NSInteger selectIndex = _dropdownListView.selectedIndex;
    if (selectIndex == 0) { // 录制并编码
        if (self.captureSession == nil) {
            // 1、初始化AVCaptureSession
            self.captureSession = [[AVCaptureSession alloc] init];
            
            // 2、获取音频设备对象
            AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            
            // 3、根据音频设备对象生成对应的音频输入对象，并将该音频输入对象添加到AVCaptureSession中
            self.audioCaptureInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:nil];
            if ([self.captureSession canAddInput:self.audioCaptureInput]) {
                NSLog(@"添加了输入");
                [self.captureSession addInput:self.audioCaptureInput];
            }
            
            // 4、创建音频数据输出对象并将该输出对象添加到AVCaptureSession中
            self.audioCaptureOutput = [[AVCaptureAudioDataOutput alloc] init];
            if ([self.captureSession canAddOutput:self.audioCaptureOutput]) {
                NSLog(@"添加了输出");
                [self.captureSession addOutput:self.audioCaptureOutput];
            }
            
            // 5、设置音频输出对象的回调
            [self.audioCaptureOutput setSampleBufferDelegate:self queue:_audioQueue];
            
            // 6、启动运行
            [self.captureSession startRunning];
            
            NSString *aacSavePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
            aacSavePath = [aacSavePath stringByAppendingPathComponent:@"test.aac"];
            NSLog(@"目录 %@",aacSavePath);
            if (_dataWriter == nil) {
                _dataWriter = [[AudioDataWriter alloc] initWithPath:aacSavePath];
            }
            [_dataWriter deletePath];
        }
    } else {    // 解码并播放
        
    }
}

/** CMSampleBufferRef 一个描述音视频数据对象的结构体,它既可以用于描述压缩的音/视频，也可以用于描述原始的音/视频；
 *  位于CoreMedia下的CMSampleBuffer.h头文件下，一般是AVCaptureOutput生成的对象
 *  1、它包含了音/视频的数据格式
 *  2、它包含了具体的音/视频数据(压缩或者未压缩的)
 */
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.audioCaptureOutput == output) {    // 音频输出
        NSLog(@"获取到音频数据咯");
        
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        CFRetain(blockBuffer);
        size_t dataSize=0;
        char *buffer = (char*)malloc(1024*10*4);
        OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &dataSize, &buffer);
        if (status != kCMBlockBufferNoErr) {
            NSLog(@"没有出错");
        } else {
            NSLog(@"获取的数据大小 %ld",dataSize);
        }
        
        if (_encoder == nil) {
            // 初始化
            AudioStreamBasicDescription inASBD = *CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer));
            _encoder = [[AudioHardCodec alloc] initWithPCMToAAC:inASBD];
            
            // 初始化解码器;因为是将编码的数据直接解码
            _decoder = [[AudioHardCodec alloc] initWithAACToPCM:inASBD];
        }
        
        // 输入音频的数据格式
        size_t size;
        const AudioChannelLayout *layout =  CMAudioFormatDescriptionGetChannelLayout(CMSampleBufferGetFormatDescription(sampleBuffer), &size);
        AudioBufferList inputBufferlist;
        inputBufferlist.mNumberBuffers = 1;
        inputBufferlist.mBuffers[0].mNumberChannels = AudioChannelLayoutTag_GetNumberOfChannels(layout->mChannelLayoutTag);
        inputBufferlist.mBuffers[0].mData = malloc(dataSize);
        inputBufferlist.mBuffers[0].mDataByteSize = (UInt32)dataSize;
        memcpy(inputBufferlist.mBuffers[0].mData, buffer, dataSize);
        
        NSData *outData = nil;
        if(![_encoder doEncodeBufferList:inputBufferlist toADTSData:&outData]){
            NSLog(@"编码失败");
        } else {
            [_dataWriter writeData:outData];
            
            // 尝试解码
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                AudioBufferList outList;
                if ([self->_decoder doDecodeBufferData:outData toBufferList:&outList]) {
                    NSLog(@"解码成功 size %ld channel %d samplerate %d",outList.mBuffers[0].mDataByteSize);
                }
            });
        }
    }
}

@end
