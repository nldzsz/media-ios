//
//  CodecBase.hpp
//  media
//
//  Created by 飞拍科技 on 2019/8/9.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef CodecBase_hpp
#define CodecBase_hpp
extern "C"
{
#include "CLog.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/opt.h"
#include "libavutil/timestamp.h"
}
#include <stdio.h>
#include <pthread.h>
#include "CodecDefine.h"

class CodecBase
{
// 声明为protected，这样不允许外部直接初始化此类
protected:
    CodecBase(MZCodecType type,MZCodecIDType encodeId);
// 基类的析构函数一定要声明成虚函数，这样就行程动态绑定，不会造成内存泄露
    virtual ~ CodecBase();
    
    // 重置编解码器；
    void resetWithCodecId(MZCodecType type,MZCodecIDType codecId);
    
private:
    void initEnCodecContext(MZCodecIDType type);
    void initDeCodecContext(MZCodecIDType type);
protected:
    // 是编码器还是解码器
    MZCodecType       fCodecType;
    MZCodecIDType     fCodeIdType;
    
    // 编解码上下文
    AVCodecContext  *pCodecCtx;
    // 编解码器
    AVCodec         *pCodec;
    // 原始数据
    AVFrame         *pFrame;
    // 压缩数据
    AVPacket        *pPacket;
    // 锁
    pthread_mutex_t       pMutex;
    
    enum AVCodecID getCodecIdWithId(MZCodecIDType encodeId);
};

#endif /* CodecBase_hpp */
