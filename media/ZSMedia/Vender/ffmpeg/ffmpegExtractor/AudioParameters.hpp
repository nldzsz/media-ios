//
//  AudioParameters.hpp
//  media
//
//  Created by apple on 2020/6/13.
//  Copyright © 2020 飞拍科技. All rights reserved.
//

#ifndef AudioParameters_hpp
#define AudioParameters_hpp

#include <stdio.h>
extern "C"
{
#include "CLog.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libavutil/opt.h"
}
#include "CodecDefine.h"
using namespace std;

class AudioParameters
{
public:
    AudioParameters();
    AudioParameters(MZCodecIDType audiotype,MZSampleFormat fmt,MZChannellayout ch,int bit_rate,int nb_samples);
    ~AudioParameters();
    
    // 重载 == 运算符
    bool operator==(AudioParameters paremeter);
    
    void setIdType(MZCodecIDType type);
    const MZCodecIDType getIdType();
    const enum AVCodecID avCodecId();
    void setSampleFmt(MZSampleFormat format);
    const MZSampleFormat getSampleFmt();
    void setChannelLayout(MZChannellayout ch);
    const MZChannellayout getLayout();
    void setBitRate(int bitrate);
    const int getBitRate();
    void setNBSamples(int smpls);
    const int getNBSamples();
private:
    // 音频编码类型
    MZCodecIDType   fAudioType;
    // 音频采样格式
    MZSampleFormat  fSampleFmt;
    // 音频声道类型
    MZChannellayout fChannelLayout;
    // 比特率
    int     fBitRate;
    // 每一个编码音频帧中的采样数
    int     f_nb_samples;
    
};
#endif /* AudioParameters_hpp */
