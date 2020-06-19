//
//  YuvPlayer.m
//  media
//
//  Created by 飞拍科技 on 2019/6/8.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "YuvPlayer.h"
#import <pthread.h>
#import <sys/time.h>
#import "VideoFileSource.h"

#define Video_cache_lenght 10
@interface YuvPlayer ()
{
    /** 这里设计一个队列，用于保存原始的视频帧，作为管理视频帧的缓冲队列
     *  因为这里是直接播放YUV裸数据，所以缓冲的是原始视频帧
     *  tips:一般做视频播放器的时候缓冲队列不会保存原始的视频帧，一般都是保存压缩的视频帧，因为原始的视频帧数据过大，
     *  可以算一下，1080P 30fps 的视频，缓冲一秒占用内存 1080x1920x1.5x30 = 90M
     */
    // 用于缓存原始视频帧的数组队列
    VideoFrame *_videoFrame[Video_cache_lenght];
    int _count;
    int _head;
    int _tail;
    // 保证该队列安全性的锁
    pthread_mutex_t _videoMutex;
    pthread_cond_t  _videoCond;
}

@property (assign, nonatomic) BOOL mRun;
@property (assign, nonatomic) BOOL mRenderThreadRun;
@property (assign, nonatomic) BOOL mVideoDidFnish;

// 渲染线程，当视频缓存区没有可以用于解码的数据时休眠
@property(nonatomic,strong)NSThread *renderThread;

// 保证VideoPlayer是线程安全的锁
@property(nonatomic,strong)NSLock *lock;


@end

@implementation YuvPlayer

- (id)init
{
    if (self = [super init]) {
        for (int i=0; i<Video_cache_lenght; i++) {
            _videoFrame[i] = malloc(sizeof(VideoFrame));
            memset(_videoFrame[i], 0, sizeof(VideoFrame));
        }
        _count = 0;
        _head = 0;
        _tail = 0;
        pthread_mutex_init(&_videoMutex,NULL);
        pthread_cond_init(&_videoCond, NULL);
        
        self.mRun = NO;
        self.mRenderThreadRun = NO;
        
        self.lock = [[NSLock alloc] init];
    }
    
    return self;
}
static YuvPlayer* defaultPlayer = nil;
+ (instancetype)shareInstance
{
    if(defaultPlayer == nil) {
        @synchronized (self) {
            if (defaultPlayer == nil) {
                defaultPlayer = [[self alloc] init];
            }
        }
    }
    return defaultPlayer;
}

+(void) releaseInstance {
    @synchronized (self) {
        defaultPlayer = nil;
    }
}

- (void)setVideoView:(UIView*)videoView
{
    BEGIN_DISPATCH_MAIN_QUEUE
    if (self->_renderView == nil) {
        self->_renderView = [[GLVideoView alloc] initWithFrame:videoView.bounds];
    }
    if (self->_renderView.superview != videoView) {
        [videoView addSubview:self->_renderView];
    }
    self->_renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [videoView bringSubviewToFront:self->_renderView];

    END_DISPATCH_MAIN_QUEUE
}

- (void)play
{
    BEGIN_DISPATCH_MAIN_QUEUE
    if (self.mRun) {
        NSLog(@"已经在播放流了,返回");
        return;
    }
    self.mRun = YES;
    
    [self startRenderThread];
    END_DISPATCH_MAIN_QUEUE
}

// 调用此方法后，启动一个解码线程，该线程循环从视频缓存区中提取视频进行解码，如果视频缓存区中没有视频，则休眠。
-(void)startRenderThread;
{
    if (self->_renderThread == nil) {
        self->_renderThread = [[NSThread alloc] initWithTarget:self selector:@selector(renderThreadRunloop) object:nil];
        self->_renderThread.name = @"com.previewplayer.renderThread";
        self->_renderThread.qualityOfService = NSQualityOfServiceUserInteractive;
        [self->_renderThread start];
    }
}

- (void)renderThreadRunloop
{
    NSLog(@"decodeThreadRunloop begin");
    [self.lock lock];
    self.mRenderThreadRun = YES;
    while (![NSThread currentThread].isCancelled &&(![self isEmpty] || !self.mVideoDidFnish)) {
        @autoreleasepool {
            NSLog(@"开始渲染");
            VideoFrame *frame = NULL;
            [self pullVideo:&frame];
            
            if (frame && frame->luma == NULL) {  //说明暂时没有视频数据
                NSLog(@"没有数据");
                continue;
            }
            
            [self.renderView rendyuvFrame:frame];
            NSLog(@"结束渲染");
            // 用完后释放内存
            if (frame) {
                [self freeVideoFrame:frame];
            }
            usleep(usec_per_fps);
        }
    }
    [self.lock unlock];
    NSLog(@"decodeThreadRunloop end");
}

- (void)didFinishVideoData
{
    NSLog(@"播放完毕");
    self.mVideoDidFnish = YES;
}

- (void)pushYUVFrame:(VideoFrame *)video
{
    if (video == NULL) {
        NSLog(@"数据为空，丢弃");
        return;
    }
    
    if (_mRenderThreadRun) {
        [self addVideo:video];
    } else {
        NSLog(@"渲染线程没有运行，先清除缓冲");
        [self clearCacheData];
    }
}

- (void)stop
{
    BEGIN_DISPATCH_MAIN_QUEUE
    if (!self.mRun) {
        NSLog(@"已经停止过流了,返回");
        return;
    }
    self.mRun = NO;
    [self clearCacheData];
    END_DISPATCH_MAIN_QUEUE
}

/** 1、遇到问题 free()栈内存引起的奔溃
 *  这里的frame对象实际上是栈内存,所以不能用free()来释放，会引起奔溃。
 */
- (void)freeVideoFrame:(VideoFrame*)frame
{
    pthread_mutex_lock(&_videoMutex);
    if (frame != NULL) {
        if (frame->luma != NULL) {
            free(frame->luma);
            frame->luma = NULL;
        }
        if (frame->chromaB != NULL) {
            free(frame->chromaB);
            frame->chromaB = NULL;
        }
        if (frame->chromaR != NULL) {
            free(frame->chromaR);
            frame->chromaR = NULL;
        }
        if (frame->cv_pixelbuffer != NULL) {
            free(frame->cv_pixelbuffer);
            frame->cv_pixelbuffer = NULL;
        }
        
        free(frame);
        frame = NULL;
    }
    pthread_mutex_unlock(&_videoMutex);
}

- (void)pullVideo:(VideoFrame**)frame
{
    pthread_mutex_lock(&_videoMutex);
    if(_count == 0) {
        NSLog(@"缓冲区没数据了 ");
        struct timeval tv;
        gettimeofday(&tv, NULL);
        
        struct timespec ts;
        ts.tv_sec = tv.tv_sec + 2;
        ts.tv_nsec = tv.tv_usec*1000;
        pthread_cond_timedwait(&_videoCond, &_videoMutex, &ts);
        if(_count == 0){
            pthread_mutex_unlock(&_videoMutex);
            *frame = NULL;
            return;
        }
    }
    NSLog(@"缓冲区中数据个数 %d",_count);
    VideoFrame *tmp = NULL;
    tmp = _videoFrame[_head];
    *frame = tmp;
    _head++;
    if(_head>=Video_cache_lenght)_head = 0;
    _count--;
    pthread_mutex_unlock(&_videoMutex);
}

- (BOOL)isFull
{
    return _count == Video_cache_lenght;
}
- (BOOL)isEmpty
{
    return _count == 0;
}
- (void)addVideo:(VideoFrame*)frame
{
    if (frame == NULL) {
        NSLog(@"要缓冲的frame is NULL");
        return;
    }
    
    pthread_mutex_lock(&_videoMutex);
    if([self isFull]){
        NSLog(@"缓冲区满了 丢弃帧");
        pthread_mutex_unlock(&_videoMutex);
        [self freeVideoFrame:frame];
        return;
    }
    _videoFrame[_tail] = frame;
    _tail++;
    if(_tail>=Video_cache_lenght)_tail = 0;
    _count++;
    pthread_cond_signal(&_videoCond);
    pthread_mutex_unlock(&_videoMutex);
}

- (void)clearCacheData
{
    NSLog(@"clearCacheData ");
    pthread_mutex_lock(&_videoMutex);
    for (int i=0; i<_count; i++) {
        if (_videoFrame[i]->luma != NULL) {
            free(_videoFrame[i]->luma);
            _videoFrame[i]->luma = NULL;
        }
        if (_videoFrame[i]->chromaB != NULL) {
            free(_videoFrame[i]->chromaB);
            _videoFrame[i]->chromaB = NULL;
        }
        if (_videoFrame[i]->chromaR != NULL) {
            free(_videoFrame[i]->chromaR);
            _videoFrame[i]->chromaR = NULL;
        }
        if (_videoFrame[i]->cv_pixelbuffer != NULL) {
            free(_videoFrame[i]->cv_pixelbuffer);
            _videoFrame[i]->cv_pixelbuffer = NULL;
        }
        free(_videoFrame[i]);
        _videoFrame[i] = NULL;
    }
    _count = 0;
    _head = 0;
    _tail = 0;
    pthread_mutex_unlock(&_videoMutex);
}


@end
