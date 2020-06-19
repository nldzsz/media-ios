//
//  VideoParameters.cpp
//  media
//
//  Created by apple on 2019/8/31.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#include "VideoParameters.hpp"

// VideoParameters ============ //
VideoParameters::VideoParameters()
{
    fCodecIdType = MZCodecIDTypeH264;
    LOGD("VideoCodecEncoderParameters()");
}

VideoParameters::VideoParameters(MZCodecIDType type,int width,int height,MZPixelFormat pixelformat,int fps,int brate,int gopsize,int bframes)
:fCodecIdType(type),fWidth(width),fHeight(height),fPixelFormat(pixelformat),fFps(fps),fBitrate(brate),fGOPSize(gopsize),fBFrameNum(bframes)
{
    LOGD("VideoCodecEncoderParameters(....)");
}

//VideoParameters::VideoParameters(VideoParameters &par)
//{
//    LOGD("VideoCodecEncoderParameters(const VideoParameters &par)");
//
//}

VideoParameters::~VideoParameters()
{
    LOGD("~VideoCodecEncoderParameters()");
}

bool VideoParameters::operator==(VideoParameters paremeter)
{
    VideoParameters par = paremeter;
    if (par.fCodecIdType != fCodecIdType) {
        LOGE("fCodecIdType not eqeal");
        return false;
    }
    
    if (par.getBitrate() != fBitrate){
        LOGE("fBitrate not eqeal");
        return false;
    }
    
    if (par.getWidth() != fWidth) {
        LOGE("fBitrate not eqeal");
        return false;
    }
    
    if (par.getHeight() != fHeight) {
        LOGE("fHeight not eqeal");
        return false;
    }
    if (par.getFps() != fFps) {
        LOGE("fFps not eqeal");
        return false;
    }
    if (par.getGOPSize() != fGOPSize) {
        LOGE("fGOPSize not eqeal");
        return false;
    }
    if (par.getBFrameNum() !=fBFrameNum) {
        LOGE("fBFrameNum not eqeal");
        return false;
    }
    if (par.getPixelFormat() !=fPixelFormat) {
        LOGE("fPixelFormat not eqeal");
        return false;
    }
    
    return true;
}
void VideoParameters::setCodeIdType(MZCodecIDType type)
{
    fCodecIdType = type;
}
const MZCodecIDType VideoParameters::getCodecIdType()
{
    return fCodecIdType;
}
const enum AVCodecID VideoParameters::avCodecId()
{
    enum AVCodecID codecId = AV_CODEC_ID_H264;
    return codecId;
}
const int VideoParameters::getWidth()
{
    return fWidth;
}
void VideoParameters::setWidth(int width)
{
    fWidth = width;
}
const int VideoParameters::getHeight()
{
    return fHeight;
}
void VideoParameters::setHeight(int height)
{
    fHeight = height;
}
const int VideoParameters::getFps()
{
    return fFps;
}
void VideoParameters::setFPS(int fps)
{
    fFps = fps;
}
const int VideoParameters::getBitrate()
{
    return fBitrate;
}
void VideoParameters::setBitrate(int bRate)
{
    fBitrate = bRate;
}
void VideoParameters::setGOPSize(int gopsize)
{
    fGOPSize = gopsize;
}
const int VideoParameters::getGOPSize()
{
    return fGOPSize;
}
const int VideoParameters::getBFrameNum()
{
    return fBFrameNum;
}
void VideoParameters::setBFrameNum(int bframes)
{
    fBFrameNum = bframes;
}
void VideoParameters::setPixelFormat(MZPixelFormat pixelformat)
{
    fPixelFormat = pixelformat;
}
const MZPixelFormat VideoParameters::getPixelFormat()
{
    return fPixelFormat;
}

const AVPixelFormat VideoParameters::avpixelformat()
{
    return AV_PIX_FMT_YUV420P;
}
