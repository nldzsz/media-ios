//
//  VideoParameters.hpp
//  media
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef VideoParameters_hpp
#define VideoParameters_hpp

extern "C"
{
#include "CLog.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/opt.h"
}

#include <stdio.h>
#include "CodecDefine.h"

class VideoParameters
{
public:
    VideoParameters();
    VideoParameters(MZCodecIDType type, int width,int height,MZPixelFormat pixelformat,int fps,int brate,int gopsize,int bframes);
    // 如果在类中没有定义拷贝构造函数，编译器会自行定义一个。如果类带有指针变量，并有动态内存分配，则它必须有一个拷贝构造函数。
//    VideoParameters(VideoParameters &par);
    ~VideoParameters();
    
    bool operator==(VideoParameters par);
    
    void setCodeIdType(MZCodecIDType type);
    const MZCodecIDType getCodecIdType();
    const enum AVCodecID avCodecId();
    void setWidth(int width);
    const int getWidth();
    void setHeight(int height);
    const int getHeight();
    void setPixelFormat(MZPixelFormat pixelformat);
    const MZPixelFormat getPixelFormat();
    const AVPixelFormat avpixelformat();
    void setFPS(int fps);
    const int getFps();
    void setBitrate(int bRate);
    const int getBitrate();
    void setGOPSize(int gopsize);
    const int getGOPSize();
    void setBFrameNum(int bframes);
    const int getBFrameNum();
public:
    MZCodecIDType fCodecIdType;
    
private:
    
    int fWidth;
    int fHeight;
    MZPixelFormat fPixelFormat;
    int fFps;
    int fBitrate;
    int fGOPSize;
    int fBFrameNum;
};

#endif /* VideoParameters_hpp */
