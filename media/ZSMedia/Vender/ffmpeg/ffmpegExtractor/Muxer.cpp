//
//  Muxer.cpp
//  media
//
//  Created by apple on 2019/9/2.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#include "Muxer.hpp"
#define Muxer_IO_buf_size (1024*1024*1)

Muxer::Muxer(string filename)
:pOFormatCtx(NULL),mMuxerOpen(false),mFilename(filename),pVideoFmt(NULL),pAudioFmt(NULL)
{
    if (filename.length() == 0) {
        LOGD("file name is null");
        return;
    }
    mFilename = filename;
    videoIndex_ou = -1;
    audioIndex_ou = -1;
    
    pthread_mutex_init(&_ffmpegmutex, NULL);
    pthread_mutex_init(&_videomutex, NULL);
    pthread_mutex_init(&_audiomutex, NULL);
}

Muxer::~Muxer()
{
    mMuxerOpen = false;
    
    pthread_mutex_lock(&_ffmpegmutex);
    if (pVideoFmt) {
        avformat_close_input(&pVideoFmt);
    }
    if (pAudioFmt) {
        avformat_close_input(&pAudioFmt);
    }
    if (pOFormatCtx) {
        avformat_free_context(pOFormatCtx);
        pOFormatCtx = NULL;
    }
    pthread_mutex_unlock(&_ffmpegmutex);
    
    pthread_mutex_lock(&_videomutex);
    for (vector<VideoPacket*>::iterator it = _videopkts.begin(); it != _videopkts.end(); it++) {
        VideoPacket *pkt = *it;
        if (pkt->data) {
            free(pkt->data);
            pkt->data = NULL;
        }
        pkt = NULL;
    }
    pthread_mutex_unlock(&_videomutex);
    
    pthread_mutex_lock(&_audiomutex);
    for (vector<AudioPacket*>::iterator it = _audiopkts.begin(); it != _audiopkts.end(); it++) {
        AudioPacket *pkt = *it;
        if (pkt->data) {
            free(pkt->data);
            pkt->data = NULL;
        }
        pkt = NULL;
    }
    pthread_mutex_unlock(&_audiomutex);
    
    pthread_mutex_destroy(&_videomutex);
    pthread_mutex_destroy(&_audiomutex);
}

void Muxer::internalRelease(AVFormatContext **fmt1,AVFormatContext **fmt2,AVFormatContext **fmt3)
{
    if (pVideoFmt) {
        avformat_close_input(fmt1);
    }
    if (pAudioFmt) {
        avformat_close_input(fmt2);
    }
    if (pOFormatCtx) {
        avformat_free_context(*fmt3);
        *fmt3 = NULL;
    }
}

/** 封装步骤
 *  1、通过avformat_alloc_output_context2()创建输出AVFormatContext，
 *  2、给AVFormatContext添加对应的输出流(音视频流)，并且为它们赋值正确的封装格式参数
 *  3、avio_open()打开输出缓冲区 然后写入文件头信息avformat_write_header();
 *  4、写入具体的音视频数据
 *  5、写入文件尾信息完成文件保存收尾工作等等
 */
bool Muxer::openMuxer()
{
    LOGD("openMuxer()");
    if (mMuxerOpen) {
        LOGD("has already openMuxer()");
        return true;
    }
    mMuxerOpen = true;
    
    int video_size = 0;
    int audio_size = 0;
    bool  open = mMuxerOpen;
    while (open && video_size < 15 && audio_size < 25) {  // 等待15个数据包的缓冲用以解析数据
        pthread_mutex_lock(&_videomutex);
        video_size = (int)_videopkts.size();
        pthread_mutex_unlock(&_videomutex);
        
        pthread_mutex_lock(&_audiomutex);
        audio_size = (int)_audiopkts.size();
        pthread_mutex_unlock(&_audiomutex);
        
        // 每次休眠10ms
        usleep(10000);
        
        open = mMuxerOpen;
    }
    
    
    int ret = 0;
    const char *in_filename = mFilename.c_str();
    AVFormatContext *in_videofmt = NULL,*in_audiofmt = NULL,*ouFmtctx = NULL;
    in_videofmt = iformatContext(this, readVideoPacket);
    in_audiofmt = iformatContext(this, readAudioPacket);
    if (!in_videofmt && !in_audiofmt) {
        LOGD("没有解析到数据");
        return false;
    }
    
    /** 1、创建用于往文件写入数据的AVFormatContext;
     *  将依次根据第二三四个参数推断出格式类型，然后创建 AVFormatContext，这里是根据文件名后缀推断
     *  会自动创建AVOutputFormat对象oformat，它代表了输出的数据格式等信息
     *  avformat_open_input()为创建从文件读取数据的AVFormatContext，会自动创建AVInputFormat对象iformat，它代表了读取到的数据的格式信息
     */
    ret = avformat_alloc_output_context2(&ouFmtctx, NULL, NULL, in_filename);
    if (ret < 0) {
        LOGD("avformat_alloc_output_context2 fail %d",ret);
        return false;
    }
    
    /** 2、给AVFormatContext添加对应的输出流(音视频流)，并且为它们赋值正确的封装格式参数
     *  AVStream用于和具体的音/视频/字母等数据流关联;对于往文件写入数据，必须在avformat_write_header()函数前手动创建
     *  对于从文件中读取数据，在其它函数内部自动创建
     */
    /** 给写入数据的AVFormatContext输出流AVStream赋值音视频的格式参数，这样封装的时候文件头信息才会正确写入。赋值格式参数有两种方式
     *  方式一：从另一个AVFormatContext所对应的AVStream中拷贝，常用语没有经过编码的二次封装
     *  方式二：从AVCodecContext编解码器上下文中拷贝
     */
    if (in_videofmt) {
        AVStream *oustream = avformat_new_stream(ouFmtctx, NULL);
        videoIndex_ou = oustream->index;
        
        // 设置视频流参数；直接从源AVFormat中拷贝
        AVStream *instream = in_videofmt->streams[0];
        avcodec_parameters_copy(oustream->codecpar, instream->codecpar);
    }
    
    /** 3、打开输出文件并和输出缓冲区关联起来并且写入头文件信息
     */
    if (!(ouFmtctx->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open2(&ouFmtctx->pb, in_filename, AVIO_FLAG_READ_WRITE, NULL, NULL);
        if (ret < 0) {
            LOGD("avio_open fail %d",ret);
            internalRelease(&in_videofmt, &in_audiofmt, &ouFmtctx);
            return false;
        }
    }
    
    // 4、写入头文件信息
    ret = avformat_write_header(ouFmtctx, NULL);
    if (ret < 0) {
        LOGD("avformat_write_header fail %d",ret);
        internalRelease(&in_videofmt, &in_audiofmt, &ouFmtctx);
        return false;
    }
    
    pOFormatCtx = ouFmtctx;
    pVideoFmt = in_videofmt;
    pAudioFmt = in_audiofmt;
    
    // 5、写入数据
    bool saw_fist_pkt = false;
    int64_t video_next_dts = AV_NOPTS_VALUE;
    while (mMuxerOpen) {
        
        AVPacket *sPacket = av_packet_alloc();
        pthread_mutex_lock(&_ffmpegmutex);
        if (pVideoFmt) {
            ret = av_read_frame(pVideoFmt, sPacket);
        }
        pthread_mutex_unlock(&_ffmpegmutex);
        if (ret < 0) {
            break;
        }
        
        if (sPacket->stream_index == 0) {
            
            pthread_mutex_lock(&_ffmpegmutex);
            AVRational src_tb,dst_tb;
            int fps = 1,delay = 1;
            if (pVideoFmt && pOFormatCtx) {
                AVStream *src_stream = pVideoFmt->streams[0];
                src_tb = src_stream->time_base;
                dst_tb = pOFormatCtx->streams[videoIndex_ou]->time_base;
                fps = src_stream->avg_frame_rate.num;
                delay = src_stream->codecpar->video_delay;
            }
            pthread_mutex_unlock(&_ffmpegmutex);
            
            /** 遇到问题：当输入文件为h264的码流时，再封装时失败
             *  分析原因：因为h264码流解析出来的AVPacket的dts和pts的值为AV_NOPTS_VALUE,如果不作处理，再封装就会出错
             *  解决方案：按照如下的公式给dts和pts重新赋值
             */
            if (!saw_fist_pkt) {
                video_next_dts = fps ? - delay * AV_TIME_BASE / fps : 0;
                saw_fist_pkt = true;
            }
            if (sPacket->dts == AV_NOPTS_VALUE) {
                sPacket->dts = video_next_dts;
                sPacket->pts = sPacket->dts;
                video_next_dts += av_rescale_q(sPacket->duration, src_tb, AV_TIME_BASE_Q);
                src_tb = AV_TIME_BASE_Q;
            }
            if (sPacket->pts != AV_NOPTS_VALUE) {
                 sPacket->pts = av_rescale_q_rnd(sPacket->pts,src_tb,dst_tb,AV_ROUND_NEAR_INF);
            }
            sPacket->dts = av_rescale_q_rnd(sPacket->dts,src_tb,dst_tb,AV_ROUND_NEAR_INF);
            sPacket->duration = av_rescale_q_rnd(sPacket->duration,src_tb,dst_tb,AV_ROUND_NEAR_INF);
            sPacket->stream_index = videoIndex_ou;
            
            LOGD("video pts %d(%s) size %d",sPacket->pts,av_ts2timestr(sPacket->pts,&dst_tb),sPacket->size);
            pthread_mutex_lock(&_ffmpegmutex);
            if (pOFormatCtx) {
                ret = av_write_frame(pOFormatCtx, sPacket);
            }
            pthread_mutex_unlock(&_ffmpegmutex);
            if (ret < 0) {
                LOGD("av_write_frame 2 fial");
                av_packet_unref(sPacket);
                break;
            }
        }

        av_packet_unref(sPacket);
    }
    
    return true;
}

void Muxer::writeVideoPacket(VideoPacket *pkt)
{
    if (!mMuxerOpen || !pkt) {
        return;
    }
    
    pthread_mutex_lock(&_videomutex);
    _videopkts.push_back(pkt);
    pthread_mutex_unlock(&_videomutex);
}

void Muxer::writeAudioPacket(AudioPacket *pkt)
{
    if (!mMuxerOpen || !pkt) {
        return;
    }
    
    pthread_mutex_lock(&_audiomutex);
    _audiopkts.push_back(pkt);
    pthread_mutex_unlock(&_audiomutex);
    
}

void Muxer::closeMuxer()
{
    mMuxerOpen = false;
    
    pthread_mutex_lock(&_ffmpegmutex);
    if (pOFormatCtx) {
        int ret = av_write_trailer(pOFormatCtx);
        if (ret < 0) {
            LOGD("av_write_trailer fail %d",ret);
        }
    }
    pthread_mutex_unlock(&_ffmpegmutex);
    
    LOGD("closeMuxer()");
    
}

AVFormatContext* Muxer::iformatContext(void *client, ReadDataFunc *readfunc)
{
    if (readfunc == NULL) {
        return NULL;
    }
    
    uint8_t *iobuf = (uint8_t*)av_mallocz(Muxer_IO_buf_size);
    if (!iobuf) {
        return NULL;
    }
    /** AVIOContext它是一个输入输出的缓冲区。作为输入缓冲区，当调用avformat_open_input()、avformat_find_stream_info()、av_read_frame()函数
     *  的时候会从该缓冲区中读取数据，然后该缓冲区会不停的从读取回调函数readFunc()中获取数据readFunc()回调函数和av_read_frame()在同一个线程
     */
    AVIOContext *ioctx = avio_alloc_context(iobuf, Muxer_IO_buf_size, 0, client, readfunc, NULL, NULL);
    if (!ioctx) {
        LOGD("io create fail");
        av_freep(&iobuf);
        return NULL;
    }
    ioctx->max_packet_size = 1024*1024;
    AVFormatContext *returnfmt = avformat_alloc_context();
    returnfmt->pb = ioctx;
    
    // 由于是通过回调函数来读数据进行解封装，所以第二个参数为NULL
    /** 遇到问题：提示"Invalid return value 0 for stream protocol"
     *  分析原因：调用此函数和avformat_find_stream_info()函数时，因为缓冲区_videopkts中没有数据，readVideoPacket()函数又return 0，给出的警告提示(实际不影响)
     *  解决方案：先缓冲一部分数据再调用此方法
     */
    int ret = avformat_open_input(&returnfmt, NULL, NULL, NULL);
    if (ret < 0) {
        avformat_close_input(&returnfmt);
        LOGD("avformat_open_input fail");
        return NULL;
    }
    ret = avformat_find_stream_info(returnfmt, NULL);
    if (ret < 0) {
        LOGD("avformat_find_stream_info fail");
        avformat_close_input(&returnfmt);
        return NULL;
    }
    
    return returnfmt;
}

int Muxer::readVideoPacket(void *client,uint8_t* buf,int buflen)
{
    Muxer *myself = (Muxer*)client;
    VideoPacket *pkt = NULL;
    pthread_mutex_lock(&myself->_videomutex);
    if (myself->_videopkts.size() > 0) {
        vector<VideoPacket*>::iterator begin = myself->_videopkts.begin();
        pkt = *begin;
        myself->_videopkts.erase(begin);
    }
    pthread_mutex_unlock(&myself->_videomutex);
    if (pkt != NULL) {
//        static int i = 0;
//        i++;
//        LOGD("consum video pkt %ld size %d",i,pkt->size);
        
        int size = FFMIN(pkt->size,buflen);
        memcpy(buf, pkt->data, size);
        free(pkt->data);
        pkt->data = NULL;
        pkt = NULL;
        return size;
    }
    /** 遇到问题：av_read_frame()函数无法结束。执行 avformat_find_streaminfo()提示"Invalid return value 0 for stream protocol"
     *  分析原因：ffmpeg源码中如果readVideoPacket()函数不返回AVERROR_EOF 则av_read_frame()内部会一直读取，导致无法结束。
     *  解决方案：返回AVERROR_EOF结束本次流式读取
     */
    if (!myself->mMuxerOpen) {
        LOGD("AVERROR_EOF");
        return AVERROR_EOF;
    }
    
    // 代表缓冲区暂时没有数据了，内部会等待
    return 0;
}

int Muxer::readAudioPacket(void *client,uint8_t* buf,int buflen)
{
    
    return AVERROR_EOF;
}
