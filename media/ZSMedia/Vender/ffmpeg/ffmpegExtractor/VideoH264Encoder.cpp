//
//  VideoCodecEncoder.cpp
//  media
//
//  Created by 飞拍科技 on 2019/8/12.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#include "VideoH264Encoder.hpp"

VideoH264Encoder::VideoH264Encoder()
:CodecBase(MZCodecTypeEncoder,MZCodecIDTypeH264)
{
    LOGD("VideoH264Encoder()");
    fFramecount = 0;
    fOpenedEncoder = false;
}

VideoH264Encoder::VideoH264Encoder(const VideoParameters& par)
:CodecBase(MZCodecTypeEncoder,par.fCodecIdType)
{
    LOGD("VideoH264Encoder()");
    fFramecount = 0;
    fOpenedEncoder = false;
}

VideoH264Encoder::~VideoH264Encoder()
{
    
}

/** 遇到问题：指针变量fParameters被提前释放了
 *  解决方案：由于从外面传递过来的参数parameters是栈变量，而这里fParameters = &pram;简单的将fParameters简单的指向栈变量地址导致当栈变量释放后这里的地址内容也被收回了；将引用
 *  类型参数换成普通变量类型
 */
void VideoH264Encoder::setParameters(VideoParameters pram)
{
    if (!checkParametersValidate(pram)) {
        LOGD("checkParametersValidate fail");
        return;
    }
    
    if (!(pram == fParameters)) {
        fCodeIdType = pram.fCodecIdType;
        fParameters = pram;
        // 重置编码器
        resetWithCodecId(MZCodecTypeEncoder, fCodeIdType);
        fFramecount = 0;
    }
    
    /** 遇到问题：avcodec_open2()出错
     *  解决方案：在avcodec_open2()之前设置编码参数
     */
    AVCodecID codeid = getCodecIdWithId(fCodeIdType);
    // 编码方式Id 比如h264
    pCodecCtx->codec_id = codeid;
    // 类型，这里为视频
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    // 原始视频的数据类型
    pCodecCtx->pix_fmt = pram.avpixelformat();
    // 编码后的平均码率； 单位bit/s
    pCodecCtx->bit_rate = pram.getBitrate();
    // 视频编码用的时间基单位,这里为{1,fps},此项设置必须有;那么AVFrame的pts=1/fps*time_base.den*frame_index
    pCodecCtx->time_base = av_make_q(1, pram.getFps());
    // 帧率，用于决定编码后的帧率；如果time_base为{1,fps}，这里可以省略设置
    pCodecCtx->framerate = (AVRational){pram.getFps(), 1};
    // 视频宽，高
    pCodecCtx->width = pram.getWidth();
    pCodecCtx->height = pram.getHeight();
    // GOP size
    pCodecCtx->gop_size = pram.getGOPSize();
    // 一组 gop中b frame 的数目
    pCodecCtx->max_b_frames = pram.getBFrameNum();
    // 每一帧图像中的slices数目，默认为0
    pCodecCtx->slices = 5;
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 50;
    
    if ((pCodecCtx->codec->capabilities & AV_CODEC_FLAG_LOW_DELAY)){
        LOGD("ddddd");
    }
    
    // x264编码特有的参数
    if (codeid == AV_CODEC_ID_H264) {
        av_opt_set(pCodecCtx->priv_data, "preset", "slow", 0);
        
        /** 遇到问题：将H264视频码流封装到MP4中后，无法播放；
         *  解决方案：加入如下代码
         *  Some formats want stream headers to be separate
         */
        pCodecCtx->flags |= AV_CODEC_FLAG2_LOCAL_HEADER;
    }
}

bool VideoH264Encoder::openEncoder()
{
    // 如果没有检测到，则重置一下编码器
    if (pCodecCtx == nullptr) {
        setParameters(fParameters);
    }
    
    if (fOpenedEncoder) {
        LOGD("fOpenedEncoder is opened return");
        return true;
    }
    
    int ret = avcodec_open2(pCodecCtx, pCodec, NULL);
    if (ret < 0) {
        LOGD("avcodec_open2 fail %d",ret);
        fOpenedEncoder = false;
        return false;
    }
    
    fOpenedEncoder = true;
    return true;
}

bool VideoH264Encoder::canUseEncoder()
{
    return fOpenedEncoder;
}

void VideoH264Encoder::flushEncoder()
{
    if (!fOpenedEncoder) {
        return;
    }
    
    if (pCodecCtx == NULL) {
        LOGD("flushEncoder() but codecCtx is NULL");
        return;
    }
    doEncode(NULL);
}

void VideoH264Encoder::closeEncoder()
{
    internalRelase();
}

/** ffmpeg 编码器的设计架构为：输入原始数据-->编码输入缓冲区-->编码器-->编码输出缓冲区-->输出编码数据
 *  有可能输入了一帧原始数据到输入缓冲区，但是编码器并没有开始编码，导致编码输出缓冲区并没有数据;那此时就要再发送一个NULL数据到
 *  输入缓冲区，然后再次从输出缓冲区获取数据
 */
void VideoH264Encoder::sendRawVideoAndReceivePacketVideo(VideoFrame *frame)
{
    // 检查AVFrame是否为NULL
    if (pFrame == NULL) {
        pFrame = av_frame_alloc();

        pFrame->width = pCodecCtx->width;
        pFrame->height = pCodecCtx->height;
        pFrame->format = pCodecCtx->pix_fmt;
        // 为AVFrame分配存放视频数据的内存；av_frame_alloc()只是创建了不包含视频数据的内存
        /** 遇到问题：编码后h264文件播放视频画面有绿条
         *  分析原因：源yuv为480x640的yuv420p方式存储时，由于源yuv文件yuv数据存储时不是按字节对齐方式存储的，而这里创建的AVFrame又是按照
         *  字节对齐的方式分配内存的即linesize的大小和480不相等，导致数据错乱。
         *  解决方案：
         *  1、从源yuv文件读取数据到AVFrame时linesize要和yuv的宽对应，所以这里要将av_frame_get_buffer()的第二个参数设置为1；
         *  2、如果av_frame_get_buffer()第二个参数为0，则从源yuv文件读取数据到AVFrame时要按照字节对齐的方式重新进行排列(即每一行要空出一部分字节)
         */
        av_frame_get_buffer(pFrame, 1);
        // 可写的含义为：引用计数为1并且为非Read_only
        av_frame_make_writable(pFrame);
    }
    
    // 检查AVCodecContext是否为NULL
    if (pCodecCtx == NULL) {
        resetWithCodecId(fCodecType, fCodeIdType);
    }
    
    if (frame == NULL || frame->luma == NULL) {
        LOGD("即将结束编码");
    } else {
       
        // 先将以前的值清空
        memset(pFrame->data[0], 0, pFrame->linesize[0]);
        memset(pFrame->data[1], 0, pFrame->linesize[1]);
        memset(pFrame->data[2], 0, pFrame->linesize[2]);
        
        memcpy(pFrame->data[0], frame->luma, frame->width*frame->height);
        memcpy(pFrame->data[1], frame->chromaB, frame->width*frame->height/4);
        memcpy(pFrame->data[2], frame->chromaR, frame->width*frame->height/4);
        
        /** 遇到问题：x264编码警告[libx264 @ 0x112800c00] non-strictly-monotonic PTS
         *  解决方案：传入编码器的AVFrame中的pts没有依次递增;依次递增就好
         */
        pFrame->pts = fFramecount * pCodecCtx->time_base.den/pCodecCtx->framerate.num;
        fFramecount +=1;
//        LOGD("编码 编号 %d",fFramecount);
        
        doEncode(pFrame);
    }
}

void VideoH264Encoder::setEncodeCallback(void*client,EncodeCallback *callback)
{
    fEncodeClient = client;
    fEncodeCallback = callback;
}

/** 编码时间记录：
 *  1、640x480分辨率 30fps 0.96Mbps:
 *  iPhone6(10秒，GOP 30，无B帧，总15秒，55ms/帧；含1个B帧，总16秒 59ms/帧；GOP 60，无B帧，总15.5秒，57ms/帧)最大内存64M
 *  iPhoneX(11秒，GOP 30，无B帧，总3.5秒 13ms/帧;含1个B帧，总3.5秒 13ms/帧；GOP 60，无B帧，总4秒，14ms/帧)最大内存112M
 *  2、1280x720 30fps 2.56Mbps:
 *  iPhone6(10秒，GOP 30，无B帧，总28秒，140ms/帧；含1个B帧，总42秒 209ms/帧；GOP 60，无B帧，总36秒，179ms/帧)最大内存155M
 *  iPhoneX(10秒，GOP 30，无B帧，总7秒 26ms/帧;含1个B帧，总11秒 43ms/帧；GOP 60，无B帧，总8秒，28ms/帧)最大内存222M
 *  3、1920x1080 30fps 5.12Mbps:
 *  iPhone6(10秒，GOP 30，无B帧，总28秒，309ms/帧；含1个B帧，总42秒 454ms/帧；GOP 60，无B帧，总32秒，348ms/帧)
 *  iPhoneX(12秒，GOP 30，无B帧，总16秒 60ms/帧;含1个B帧，总23秒 87ms/帧；GOP 60，无B帧，总17秒，64ms/帧)
 *  4、1920x1080 30fps 20Mbps:
 *  iPhoneX(10秒，GOP 30，无B帧，总17秒 201ms/帧;含1个B帧，总35秒 408ms/帧；GOP 60，无B帧，内存不够终止) 最大内存1.5G
 *  总结：
 *  1、相同分辨率，码率越大，帧率越小，GOP越大，B帧越多，每帧编码越耗时
 *  2、分辨率越大，每帧编码越耗时
 */
/** 默认的视频编码规则：
 *  1、编码后输出的每个AVPacket包最多包含一个视频帧，如果是I帧，此AVPacket中还包括SPS和PPS信息
 *  2、ffmpeg自动为我们再每个I/B/P/SPS/PPS数据的前面填充上了0001或者001，貌似I帧前面是001，其它是0001，所以直接将AVPacket的data字段写入文件就是h264码流了
 */
void VideoH264Encoder::doEncode(AVFrame *frame)
{
    /** return
     *  AVERROR(EAGAIN); -35 编码器接收缓冲区已经满了，得先调用avcodec_receive_packet()清空一下
     *  AVERROR(EINVAL); -22 编码器没有打开
     *  AVERROR_EOF;编码器已经处于flushed状态了，无法再接收AVFrame了
     *  其它错误
     *  不管avcodec_send_frame()返回什么错误，这里可以不用做处理，所有的处理放到avcodec_receive_packet这一步进行
     */
    /** 遇到问题：输入的原始视频帧的个数和输出的压缩视频帧的个数不一致
     *  解决方案：由于输入和输出并不是依次对应的，再输入完所有的原始视频帧后，要想获得所有压缩的编码视频数据，则
     *  avcodec_send_frame()第二个参数传NULL即可
     */
    int ret = avcodec_send_frame(pCodecCtx, frame);
    
    if (ret != 0) {
        LOGD("avcodec_send_frame fail %d",ret);
        return;
    }
    
    AVPacket *pkt = av_packet_alloc();
    while (true) {
        /** return
         *  AVERROR(EAGAIN); -35 编码器输出缓冲区已经空了(已无编码好的数据了)
         *  AVERROR_EOF;编码器已经处于flushed状态了，无法再输出编码数据了
         *  其它错误
         */
        ret = avcodec_receive_packet(pCodecCtx, pkt);
        
        if (ret == AVERROR(EAGAIN)) {
            break;
        } else if (ret == AVERROR_EOF) {
            LOGD("avcodec_receive_packet finish %d",ret);
            break;
        } else if (ret < 0) {
            LOGD("avcodec_receive_packet fail %d",ret);
            break;
        }
        
        // 回调出去
        if (fEncodeCallback != NULL) {
            
            VideoPacket *rpkt = (VideoPacket*)malloc(sizeof(VideoPacket));
            rpkt->data = (uint8_t*)av_mallocz(pkt->size);
            rpkt->size = pkt->size;
            rpkt->width = fParameters.getWidth();
            rpkt->height = fParameters.getHeight();
            memcpy(rpkt->data, pkt->data, pkt->size);
            
            // 回调
            fEncodeCallback(fEncodeClient,rpkt);
        }
        LOGD("avcodec_receive_packet sucess pts %d(%s)",pkt->pts,av_ts2timestr(pkt->pts,&pCodecCtx->time_base));
        // 释放内存
        av_packet_unref(pkt);
    }
    
    av_packet_free(&pkt);
}

/** 遇到问题：当avcodec_send_frame()第二个参数传入NULL结束编码后，内存没有及时释放；
 *  解决方案：这是由于avcodec_send_frame()函数内部会copy一份到编码器缓冲中，所以编码结束后要释放AVCodecContext
 */
void VideoH264Encoder::internalRelase()
{
    LOGD("internalRelase()");
    fOpenedEncoder = false;
    
    if (pFrame) {
        av_frame_free(&pFrame);
    }
    if (pCodecCtx) {
        avcodec_free_context(&pCodecCtx);
    }
}

void VideoH264Encoder::safeSendRawVideoFrame(VideoFrame *frame)
{
    
}

bool VideoH264Encoder::safeReceiveEncodedFrame(VideoPacket *packet)
{
    
    return true;
}

void VideoH264Encoder::resetFrame()
{
    if (pFrame) {
        
    }
}

bool VideoH264Encoder::checkParametersValidate(VideoParameters parameters)
{
    VideoParameters par = parameters;
    bool ok = true;
    if (par.getBitrate() <= 0) {
        ok = false;
        LOGE("par.getBitrate() <=0");
    }
    
    if (par.getWidth() <= 0) {
        ok = false;
        LOGE("getWidth() <=0");
    }
    
    if (par.getHeight() <= 0) {
        ok = false;
        LOGE("getHeight() <=0");
    }
    
    if (par.getFps() <= 0) {
        ok = false;
        LOGE("getFps() <=0");
    }
    
    if (par.getGOPSize() <= 0) {
        ok = false;
        LOGE("getGOPSize() <=0");
    }
    
    return ok;
}
