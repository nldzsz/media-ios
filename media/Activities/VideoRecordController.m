//
//  VideoRecordController.m
//  media
//
//  Created by 飞拍科技 on 2019/7/22.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "VideoRecordController.h"
#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "DataWriter.h"
#import "MZCommonDefine.h"
#import "SFVideoEncoder.h"
#import "ADVTEncoder.h"
#import "FileMuxer.h"

/** 使用相机必须在info.plist中申请NSCameraUsageDescription权限
 */
@interface VideoRecordController ()<AVCaptureVideoDataOutputSampleBufferDelegate,VideoEncodeDelegate>
{
    dispatch_queue_t captureQueue;  // 采集数据的线程
    dispatch_queue_t encodeQueue;  // 编码数据的线程
    
    uint8_t *bufForY,*bufForU,*bufForV;
    BOOL    isEncoding;
    int     _width,_height; // 录制视频的宽和高
    
    // 软编码器
    SFVideoEncoder          *_sfVideoEncoder;
    // 硬编码器
    ADVTEncoder             *_hwVideoEncoder;
    // 采集画面时就进行编码
    BOOL                    _hwEncodeWhenCapture;
    id<VideoEncodeProtocal> _encoder;
    VideoCodecParameter     *_videopar;
    FileMuxer               *_fileMuxer;
    
    // 定时器，用来记录视频录制的时间
    dispatch_source_t _timer;
}
@property (strong, nonatomic) UIButton *beginButton;
@property (strong, nonatomic) UIButton *hardEncodeButton;
@property (strong, nonatomic) UIButton *softEncodeButton;
@property (strong, nonatomic) UILabel  *infoLabel;

// ====AVFoundation 框架接口===//
/** <AVFoundation>框架定义了如下摄像头管理，视频数据输出，摄像头数据渲染等接口
 */
// 管理视频输入输出的会话(输入：摄像头；输出：输送数据给app端)
@property (strong, nonatomic) AVCaptureSession          *mCaptureSession;
// 代表具体的视频输入设备(如前置摄像头或者后置摄像头)
@property (strong, nonatomic) AVCaptureDeviceInput      *mCaptureInput;
// 代表具体视频数据输出端口(APP从这个对象里面读取摄像头真实采集的视频数据)
@property (strong, nonatomic) AVCaptureVideoDataOutput  *mVideoDataOutput;
// 内置的视频渲染CALayer的子类，专门用于渲染从摄像头输出的图像
@property (strong, nonatomic) AVCaptureVideoPreviewLayer*mVideoPreviewLayer;
// ===== AVFoundation 框架接口===

@property (strong, nonatomic) DataWriter           *mDataWriter;
@property (strong, nonatomic) NSString             *mSavePath;
// 开始时间
@property (assign, nonatomic) NSInteger            mTimerCount;

@end

@implementation VideoRecordController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    /** @(按钮)开启摄像头采集
     *  点击此按钮后，将开始开启摄像头进行视频数据的采集同时将采集到的数据渲染到mVideoPreviewLayer上面实时显示，同时保存采集到的视频数据到
     *  @(按钮)硬编码
     *  将采用IOS的VideoToolbox框架提供的硬编码接口进行编码
     *  @(按钮)软编码
     *  将采用ffmpeg接口提供的接口进行软编码
     */
    self.beginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.beginButton.frame = CGRectMake(60, 50, 100, 50);
    [self.beginButton setTitle:@"开启摄像头" forState:UIControlStateNormal];
    [self.view addSubview:self.beginButton];
    [self.beginButton addTarget:self action:@selector(onTapVideoCaptureBtn:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *hardEncode = [UIButton buttonWithType:UIButtonTypeSystem];
    hardEncode.frame = CGRectMake(170, 50, 60, 50);
    [hardEncode setTitle:@"硬编码" forState:UIControlStateNormal];
    [self.view addSubview:hardEncode];
    [hardEncode addTarget:self action:@selector(onTapEncodeBtn:) forControlEvents:UIControlEventTouchUpInside];
    self.hardEncodeButton = hardEncode;
    
    UIButton *softEncode = [UIButton buttonWithType:UIButtonTypeSystem];
    softEncode.frame = CGRectMake(240, 50, 60, 50);
    [softEncode setTitle:@"软编码" forState:UIControlStateNormal];
    [self.view addSubview:softEncode];
    [softEncode addTarget:self action:@selector(onTapEncodeBtn:) forControlEvents:UIControlEventTouchUpInside];
    self.softEncodeButton=softEncode;
    
    self.infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 100, 350, 60)];
    self.infoLabel.backgroundColor = [UIColor blackColor];
    self.infoLabel.textColor = [UIColor whiteColor];
    self.infoLabel.font = [UIFont systemFontOfSize:8];
    [self.view addSubview:self.infoLabel];
    
    
    // 录制视频的保存路径；视频数据一般分为YUV和RGB两种格式
    self.mSavePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.yuv"];
    NSLog(@"路径==>%@",self.mSavePath);
    self.mDataWriter = [[DataWriter alloc] initWithPath:self.mSavePath];
    if ([self.mDataWriter fileIsExsits]) {
        self.infoLabel.text = @"本地有缓存的视频文件abc.yuv(点击\"硬编码\"或者\"软编码\" 开始编码)";
    } else {
        self.infoLabel.text = @"本地无视频文件,点击\"开启摄像头\" 开始录制";
    }
    
     /**
      * 编码参数
      */
    // 这里_width和_height的值要和下面self.mCaptureSession.sessionPreset = AVCaptureSessionPreset640x480;的对应上，编码时用得到
    _width = 480;_height = 640;
   
    // H264各个分辨率推荐的码率表:http://www.lighterra.com/papers/videoencodingh264/
    int avgbitRate = 2.56*1000000;
    /** 遇到问题：编码器缓冲的视频帧数量过大导致内存暴涨
     *  解决方案：经过调试，发现编码器缓存的视频数目=gopsize+b帧数目+4；通过控制gopsize和b帧数目来控制缓存的视频数目大小
     */
    _videopar = [[VideoCodecParameter alloc] initWithWidth:_width height:_height pixelformat:MZPixelFormatYUV420P fps:30 gop:10 bframes:0 bitrate:avgbitRate];
    // 初始化软编码器
    _sfVideoEncoder = [[SFVideoEncoder alloc] init];
    _sfVideoEncoder.delegate = self;
    [_sfVideoEncoder setParameters:_videopar];
    
   // 初始化硬编码器
    _hwVideoEncoder = [[ADVTEncoder alloc] init];
//    _hwVideoEncoder.delegate = self;
    [_hwVideoEncoder setParameters:_videopar];
    
    // 采集视频时就开启硬编码
//    _hwEncodeWhenCapture = YES;
    
    // 避免频繁创建内存
    bufForY = NULL;
    bufForU = NULL;
    bufForV = NULL;
}
- (void)intEncoder
{
    
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)onTapVideoCaptureBtn:(UIButton*)btn
{
    if (self.mCaptureSession.isRunning) {
        self.infoLabel.text = [NSString stringWithFormat:@"录制时间 %ld 秒(已保存到本地文件abc.yuv)",self->_mTimerCount];
        
        // 如果正在采集视频，通过此方式停止采集视频
        [self.mCaptureSession stopRunning];
        self.mCaptureSession = nil;
        
        [self.beginButton setTitle:@"开启摄像头" forState:UIControlStateNormal];
        self.hardEncodeButton.enabled = YES;
        self.softEncodeButton.enabled = YES;
        if (_timer) {
            dispatch_cancel(_timer);
            _timer = nil;
        }
        _mTimerCount = 0;
        return;
    }
    
    [self.mDataWriter deletePath];
    NSString *path = [self h264FilePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    
    // 因为视频采集可能比较耗时，所以需要定义一个专门的队列来采集视频数据
    if (!captureQueue) {
        captureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    
    [self.beginButton setTitle:@"停止" forState:UIControlStateNormal];
    if (!_timer) {
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(_timer, ^{
            self->_mTimerCount++;
            self.infoLabel.text = [NSString stringWithFormat:@"录制时间 %ld 秒",self->_mTimerCount];
        });
        dispatch_resume(_timer);
    }
    
    self.hardEncodeButton.enabled = NO;
    self.softEncodeButton.enabled = NO;
    [self initVideoCaptureSession];
    [self startRunCapSession];
}

- (void)onTapEncodeBtn:(UIButton*)btn
{
    if (isEncoding) {
        isEncoding = NO;
        [self endEncode];
        NSLog(@"endSoft %d",isEncoding);
    } else {
        if ([self.mDataWriter fileIsExsits]) {
            // 清空显示信息
            self.infoLabel.text = @"编码中";
            
            // 参数
            if (!_videopar) {
                // H264各个分辨率推荐的码率表:http://www.lighterra.com/papers/videoencodingh264/
                int avgbitRate = 2.56*1000000;
                /** 遇到问题：编码器缓冲的视频帧数量过大导致内存暴涨
                 *  解决方案：经过调试，发现编码器缓存的视频数目=gopsize+b帧数目+4；通过控制gopsize和b帧数目来控制缓存的视频数目大小
                 */
                _videopar = [[VideoCodecParameter alloc] initWithWidth:_width height:_height pixelformat:MZPixelFormatYUV420P fps:30 gop:10 bframes:0 bitrate:avgbitRate];
            }
            
            if (btn == self.softEncodeButton) {
                // 初始化软编码器
                _sfVideoEncoder = [[SFVideoEncoder alloc] init];
                _sfVideoEncoder.delegate = self;
                
                [_sfVideoEncoder setParameters:_videopar];
                _encoder = _sfVideoEncoder;
                
                self.hardEncodeButton.enabled = NO;
                self.beginButton.enabled = NO;
                self.softEncodeButton.titleLabel.text = @"停止";
            } else if (btn == self.hardEncodeButton) {
                // 初始化硬编码器
                _hwVideoEncoder = [[ADVTEncoder alloc] init];
                _hwVideoEncoder.delegate = self;
                
                [_hwVideoEncoder setParameters:_videopar];
                _encoder = _hwVideoEncoder;
                
                self.softEncodeButton.enabled = NO;
                self.beginButton.enabled = NO;
                self.hardEncodeButton.titleLabel.text = @"停止";
            }
            
            isEncoding = YES;
            [self performSelectorInBackground:@selector(beginEncode) withObject:nil];
        } else {
            self.infoLabel.text = @"文件不存在!";
        }
    }
}

- (void)initVideoCaptureSession
{
    // 初始化AVCaptureSession
    self.mCaptureSession = [[AVCaptureSession alloc] init];
    // 配置输出图像的分辨率;
    self.mCaptureSession.sessionPreset = AVCaptureSessionPreset640x480;
    
    /** AVCaptureDevice
     *  代表了一个具体的物理设备，比如摄像头(前置/后置)，扬声器等等
     *  备注：模拟器无法运行摄像头相关代码
     */
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    
    // 根据物理设备创建输入对象
    self.mCaptureInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:nil];
    
    // 将AVCaptureDeviceInput对象添加到AVcaptureSession中进行管理；添加之前检查一下是否支持该设备类型
    // AVCaptureDeviceInput是AVCaptureInput(它是一个抽象类)的子类
    if ([self.mCaptureSession canAddInput:self.mCaptureInput]) {
        [self.mCaptureSession addInput:self.mCaptureInput];
    }
    
    // 创建视频输出对象AVCaptureVideoDataOutput对象；AVCaptureVideoDataOutput是
    // AVCaptureOutput(它是一个抽象类)的子类
    self.mVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    // 当回调因为耗时操作还在进行时，系统对新的一帧图像的处理方式，如果设置为YES，则立马丢弃该帧。
    // NO，则缓存起来(如果累积的帧过多，缓存的内存将持续增长)；该值默认为YES
    self.mVideoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    /** 设置采集的视频数据帧的格式。这里代表生成的图像数据为YUV数据，颜色范围是full-range的
     *  并且是bi-planner存储方式(也就是Y数据占用一个内存块;UV数据占用另外一个内存块)
     *  对于相机，只支持420v(ios5 前使用)，420f(颜色范围更广，一般用这个)，BGRA三种格式
     */
//    NSArray *avails = [self.mVideoDataOutput availableVideoCVPixelFormatTypes];
//    for (NSNumber *cur in avails) {
//        NSInteger n = cur.integerValue;
//        NSLog(@"log %c%c%c%c",(n>>24)&0xFF,(n>>16)&0xFF,(n>>8)&0xFF,n&0xFF);
//    }
    [self.mVideoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    // 设置视频输出的回调代理
    [self.mVideoDataOutput setSampleBufferDelegate:self queue:captureQueue];
    if ([self.mCaptureSession canAddOutput:self.mVideoDataOutput]) {
        [self.mCaptureSession addOutput:self.mVideoDataOutput];
    }
    
    /** AVCaptureConnection代表了AVCaptureInputPort和AVCaptureOutput、
     *  AVCaptureVideoPreviewLayer之间的连接通道，通过它可以将视频数据输送给
     *  AVCaptureVideoPreviewLayer进行显示
     *  设置输出视频的输出视频的方向，镜像等等。
     */
    AVCaptureConnection *connection = [self.mVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    /** AVCaptureVideoPreviewLayer是一个可以显示摄像头内容的CAlayer的子类
     *  以下代码直接将摄像头的内容渲染到AVCaptureVideoPreviewLayer上面
     */
    self.mVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.mCaptureSession];
    [self.mVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [self.mVideoPreviewLayer setFrame:CGRectMake(0, 150, self.view.frame.size.width, self.view.frame.size.height - 250)];
    [self.view.layer addSublayer:self.mVideoPreviewLayer];
}

- (void)startRunCapSession
{
    if (!self.mCaptureSession.isRunning) {
        // 删除目录重新录制
        [self.mDataWriter deletePath];
        
        [self.mCaptureSession startRunning];
    }
}
- (void)stopRunCapSession
{
    if (self.mCaptureSession.isRunning) {
        [self.mCaptureSession stopRunning];
    }
    
    [_mVideoPreviewLayer removeFromSuperlayer];
    
}

/** CMSampleBufferRef 功能如下：
 *  1、包含音视频描述信息，比如包含音频的格式描述 AudioStreamBasicStreamDescription、包含视频的格式描述 CMVideoFormatDescriptionRef
 *  2、包含音视频数据，可以是原始数据也可以是压缩数据;通过CMSampleBufferGetxxx()系列函数提取
 */
- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"被丢弃了的数据 ==>%@",[NSThread currentThread]);
}

/** 回调函数的线程不固定
 */
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    /** CVImageBufferRef 表示原始视频数据的对象；
     *  包含未压缩的像素数据，包括图像宽度、高度等；
     *  CVImageBufferRef 等同于CVPixelBufferRef
     */
    // 获取CMSampleBufferRef中具体的视频数据
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 锁住 内存块；根据官网文档的注释，不锁住可能会造成内存泄漏
    CVReturn result = CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    if (result != kCVReturnSuccess) {
        return;
    }
    
    if (_hwEncodeWhenCapture) {
        [_hwVideoEncoder enCodeWithImageBuffer:imageBuffer];
    }
    
    // 获取数据的类型;必须是CVPixelBufferGetTypeID()返回的类型
    CFTypeID imageType = CFGetTypeID(imageBuffer);
    // 由于相机录制生成的视频只支持420v，420f，BGRA三种格式，前面两种对应于ffmpeg的AV_PIX_FMT_NV12
    OSType pixelFormatType = CVPixelBufferGetPixelFormatType(imageBuffer);
    
    if (imageType == CVPixelBufferGetTypeID() && (pixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || pixelFormatType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)) {
        size_t count = CVPixelBufferGetPlaneCount(imageBuffer);
        UInt8 *yBytes = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        UInt8 *uvBytes = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
        // 代表了内存的组织方式，与CVPixelBufferGetWidthOfPlane()值不一定相等，两者没有任何联系
        size_t yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
        size_t uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
        size_t w1 = CVPixelBufferGetWidthOfPlane(imageBuffer, 0);
        size_t w2 = CVPixelBufferGetWidthOfPlane(imageBuffer, 1);
        size_t h1 = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
        size_t h2 = CVPixelBufferGetHeightOfPlane(imageBuffer, 1);
        NSLog(@"count(%ld),y(%ld),uv(%ld),w1(%ld),w2(%ld),h1(%ld),h2(%ld)thread==>%@",count,yBytesPerRow,uvBytesPerRow,w1,w2,h1,h2,[NSThread currentThread]);
        
    
        // 再写入 UV的数据
        size_t uvlen = w1*h1/4;
        if (bufForY == NULL) {
            bufForY = malloc(w1*h1);
            bufForU = malloc(uvlen);
            bufForV = malloc(uvlen);
        }
        // 每次重置数据
        memset(bufForU, 0, uvlen);
        
        /** 1、由于相机录制生成的视频只支持420v，420f，BGRA三种格式，前面两种对应于ffmpeg的AV_PIX_FMT_NV12，即UV占的字节数为Y的一半，且
         *  按照uv的顺序交叉存储
         *  2、因为x264进行编码时需要的yuv格式为yuv420p(即I420P)，所以这里先将420v/420f的格式转换成I420P的格式然后再保存到指定的文件中
         *  3、ffplay播放yuv420p的命令 ffplay -f rawvideo -pixel_format yuv420p -video_size 480x640 -framerate 30 -i abc.yuv
         *  4、ffplay播放420v/420f的命令 ffplay -f rawvideo -pixel_format nv12 -video_size 480x640 -framerate 30 -i abc.yuv
         *
         *  备注：当然也直接以420v/420f的格式存储然后在用x264编码前转换成yuv420p的格式
         */
        /** 遇到问题：ffplay播放时视频不对。
         *  解决方案：手机分辨率是垂直的，录制视频的宽和高与前面设置视频分辨率刚好是相反的，举例，比如前面设置的为640x480，实际输出画面的宽高
         *  为480x640
         */
        /** 遇到问题：iPhoneX 采集的视频保存为yuv后播放画面不正确；iphone6 就可以正常播放
         *  分析原因：IPhoneX 的yBytesPerRow和uvBytes的值跟w1不一样，以录制640x480为例，iPhoneX的yBytesPerRow和uvBytes的值为512，而w1为480，之所以会出现这样
         *  的情况是因为iPhoneX做了为了提高内存读取效率做了字节对齐，即每一行占用512个字节其中有32个字节是没有使用的，所以在进行uv分离的时候要考虑这个因素
         *  解决方案：替换成如下的写法
         */
        // I420P格式(YYYY....U......V......YYYY....U......V......YYYY....U......V......)，每一个YYYY....U......V......代表一帧视频
        for (int i=0; i<h1; i++) {
            // 拷贝实际的Y的字节数
            memcpy(bufForY+i*w1, yBytes, w1);
            yBytes += yBytesPerRow;
            if (i >= h2) {  // 因为uv的高度只有y的一半
                continue;
            }
            // 分离交叉存储的uv;
            for (int j=0; j<w2; j++) {
                bufForU[i*w2+j]=uvBytes[j*2];
                bufForV[i*w2+j]=uvBytes[j*2+1];
            }
            uvBytes += uvBytesPerRow;
        }
        [self.mDataWriter writeDataBytes:bufForY len:w1*h1];
        [self.mDataWriter writeDataBytes:bufForU len:uvlen];
        [self.mDataWriter writeDataBytes:bufForV len:uvlen];
    }
    
    // 解锁内存块
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
}


- (void)beginEncode
{
    // 以二进制方式读取文件
    FILE *yuvFile = fopen([self.mSavePath UTF8String], "rb");
    if (yuvFile == NULL) {
        NSLog(@"打开YUV 文件失败");
        return;
    }
    if (_width <= 0 || _height <= 0) {
        NSLog(@"宽度和高度不能为 0");
        return;
    }
    
    NSLog(@"开始 拉取视频 ==>%@",[NSThread currentThread]);
    NSDate *begindate = [NSDate date];
    NSInteger count = 0;
    // 读取YUV420 planner格式的视频数据，其一帧视频数据的大小为 宽*高*3/2;
    VideoFrame *frame = (VideoFrame*)malloc(sizeof(VideoFrame));
    frame->luma = (uint8_t*)malloc(_width * _height);
    frame->chromaB = (uint8_t*)malloc(_width * _height/4);
    frame->chromaR = (uint8_t*)malloc(_width * _height/4);
    frame->width = _width;
    frame->height = _height;
    frame->cv_pixelbuffer = NULL;
    frame->full_range = 0;
    
    while (isEncoding) {
        memset(frame->luma, 0, _width * _height);
        memset(frame->chromaB, 0, _width * _height/4);
        memset(frame->chromaR, 0, _width * _height/4);
        
        size_t size = fread(frame->luma, 1, _width * _height, yuvFile);
        size = fread(frame->chromaB, 1, _width * _height/4, yuvFile);
        size = fread(frame->chromaR, 1, _width * _height/4, yuvFile);
        
        if (size == 0) {
            NSLog(@"读取的数据字节为0");
            break;
        }
        
        // 开始编码
        count++;
        [_encoder encodeRawVideo:frame];
        
        // 封装到MP4文件中
        if (_fileMuxer == nil) {
            /** 初始化封装器;这里测试过保存到abc.h264,
             */
            NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.mp4"];
            _fileMuxer = [[FileMuxer alloc] initWithPath:filePath];
            // 开始写入视频到本地文件
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSLog(@"开始写入视频到本地文件");
                [self->_fileMuxer openMuxer];
                NSLog(@"结束写入视频到本地文件");
            });
        }
    }
    [_encoder flushEncode];
    
    NSTimeInterval intal = [[NSDate date] timeIntervalSinceReferenceDate] - [begindate timeIntervalSinceReferenceDate];
    NSLog(@"结束 拉取视频 编码耗时 %.2f 秒",intal);
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        self.infoLabel.text = [NSString stringWithFormat:@"编码总耗时 %.2f 秒;每帧平均耗时 %.2f 毫秒",intal,intal*1000/count];
        [self endEncode];
        
        // 关闭文件封装器
        if (self->_fileMuxer) {
            [self->_fileMuxer finishWrite];
            self->_fileMuxer = nil;
        }
    });
    
    // 释放资源
    fclose(yuvFile);
    if (frame->luma) {
        free(frame->luma);
        free(frame->chromaB);
        free(frame->chromaR);
    }
}

- (void)endEncode
{
    isEncoding = NO;
    self.softEncodeButton.enabled = YES;
    self.hardEncodeButton.enabled = YES;
    self.beginButton.enabled = YES;
    self.softEncodeButton.titleLabel.text = @"软编码";
    self.hardEncodeButton.titleLabel.text = @"硬编码";
    
    if (_encoder) {
        [_encoder closeEncoder];
        _encoder = nil;
    }
}


#pragma mark VideoEncodeProtocal
@synthesize enableWriteToh264;
@synthesize h264FilePath;

- (BOOL)enableWriteToh264
{
    return YES;
}
-(NSString*)h264FilePath
{
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc-test.h264"];
}

- (void)didEncodeSucess:(VideoPacket *)packet
{
    if (packet == NULL) {
        return;
    }
//    static int sum = 0;
//    sum++;
//    LOGD("product sum ==>%d size %d",sum,packet->size);
    if (_fileMuxer != NULL) {
        [_fileMuxer writeVideoPacket:packet];
    }
}

- (void)didEncodeFail:(NSError *)error
{
    NSLog(@"error %@",error);
}

/** 参考文章：
 *  1、http://www.enkichen.com/2017/11/26/image-h264-encode/
 *  2、http://www.enkichen.com/2018/03/24/videotoolbox/
 */
@end
