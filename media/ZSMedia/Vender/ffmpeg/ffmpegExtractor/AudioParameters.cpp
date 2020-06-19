//
//  AudioParameters.cpp
//  media
//
//  Created by apple on 2020/6/13.
//  Copyright © 2020 飞拍科技. All rights reserved.
//

#include "AudioParameters.hpp"

AudioParameters::AudioParameters()
{
    fAudioType = MZCodecIDTypeAAC;
    fSampleFmt = MZSampleFormatFloatP;
    fChannelLayout = MZChannellayoutStero;
    fBitRate = 0.9*1000000;
    f_nb_samples = 1024;
}

AudioParameters::AudioParameters(MZCodecIDType audiotype,MZSampleFormat fmt,MZChannellayout ch,int bit_rate,int nb_samples)
:fAudioType(audiotype),fSampleFmt(fmt),fChannelLayout(ch),fBitRate(bit_rate),f_nb_samples(nb_samples)
{
    
}

AudioParameters::~AudioParameters()
{
    
}

bool AudioParameters::operator==(AudioParameters paremeter)
{
    AudioParameters par = paremeter;
    if (par.fAudioType != fAudioType) {
        LOGD("audio type not eqeal");
        return false;
    }
    if (par.fSampleFmt != fSampleFmt) {
        LOGD("sample fmt not eqeal");
        return false;
    }
    if (par.fChannelLayout != fChannelLayout) {
        LOGD("channel layout not eqeal");
        return false;
    }
    if (par.fBitRate != fBitRate) {
        LOGD("audio bit rate not eqeal");
        return false;
    }
    if (par.f_nb_samples != f_nb_samples) {
        LOGD("audio samples not eqeal");
        return false;
    }
    
    return true;
}
void AudioParameters::setIdType(MZCodecIDType type)
{
    fAudioType = type;
}

const MZCodecIDType AudioParameters::getIdType()
{
    return fAudioType;
}

const enum AVCodecID AudioParameters::avCodecId()
{
    enum AVCodecID codecId = AV_CODEC_ID_AAC;
    if (fAudioType == MZCodecIDTypeMP3) {
        codecId = AV_CODEC_ID_MP3;
    }
    return codecId;
}

void AudioParameters::setSampleFmt(MZSampleFormat format)
{
    fSampleFmt = format;
}

const MZSampleFormat AudioParameters::getSampleFmt()
{
    return fSampleFmt;
}

void AudioParameters::setChannelLayout(MZChannellayout ch)
{
    fChannelLayout = ch;
}

const MZChannellayout AudioParameters::getLayout()
{
    return fChannelLayout;
}

void AudioParameters::setBitRate(int bitrate)
{
    fBitRate = bitrate;
}

const int AudioParameters::getBitRate()
{
    return fBitRate;
}

void AudioParameters::setNBSamples(int smpls)
{
    f_nb_samples = smpls;
}

const int AudioParameters::getNBSamples()
{
    return f_nb_samples;
}
