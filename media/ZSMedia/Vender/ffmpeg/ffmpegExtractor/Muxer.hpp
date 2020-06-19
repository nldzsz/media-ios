//
//  Muxer.hpp
//  media
//
//  Created by apple on 2019/9/2.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef Muxer_hpp
#define Muxer_hpp
#include <vector>
#include <string>
#include "CodecBase.hpp"
#include "VideoParameters.hpp"
#include "AudioParameters.hpp"
#include "MZCommonDefine.h"

extern "C"
{
#include <stdio.h>
#include <pthread.h>
#include <unistd.h>
#include "CLog.h"
#include "libavutil/avutil.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/timestamp.h"
}

using namespace std;
#define Max_Vector_size 20

/** 用于写入到音视频数据的封装器
 */
class Muxer
{
public:
    Muxer(string filename);
    ~Muxer();
    
    /** 打开Muxer，此方法调用后会先生成一个前面filename定义的文件；同时阻塞当前调用线程；要在其他线程内不停的调用writeVideoPacket()或者writeAudioPacket()向
     *  _videopkts和_audiopkts缓冲区写入数据
     *  备注：这两个函数的调用线程和openMuxer()不能一样
     */
    bool openMuxer();
    // 写入视频数据，前提是前面有调用addVideoStream()，否则此方法调用无效
    void writeVideoPacket(VideoPacket *pkt);
    // 写入音频数据，前提是前面有调用addAudioStream()，否则此方法调用无效
    void writeAudioPacket(AudioPacket *pkt);
    // 关闭Muxer写入数据;调用此方法后，将保存所写入数据并生成文件。
    void closeMuxer();
private:
    // 标记本次写入写入是否开启或者结束
    bool    mMuxerOpen;
    // 要保存的文件名
    string  mFilename;
    // 音视频流在封装文件中的索引
    int videoIndex_ou,audioIndex_ou;
    // 用于写入数据的上下文
    AVFormatContext *pOFormatCtx;
    AVFormatContext *pVideoFmt;
    AVFormatContext *pAudioFmt;
    pthread_mutex_t _ffmpegmutex;
    pthread_mutex_t _videomutex;
    pthread_mutex_t _audiomutex;
    vector<VideoPacket*>_videopkts;
    vector<AudioPacket*>_audiopkts;
    
    // 用于读取音视频流的回调函数
    typedef int ReadDataFunc(void *client,uint8_t* buf,int buflen);
    AVFormatContext *iformatContext(void *client,ReadDataFunc readfunc);
    static int readVideoPacket(void *client,uint8_t* buf,int buflen);
    static int readAudioPacket(void *client,uint8_t* buf,int buflen);
    void internalRelease(AVFormatContext **infmt1,AVFormatContext **infmt2,AVFormatContext **oufmt3);
};
#endif /* Muxer_hpp */
