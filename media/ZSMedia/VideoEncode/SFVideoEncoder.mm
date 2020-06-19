//
//  SFVideoEncoder.m
//  media
//
//  Created by 飞拍科技 on 2019/7/22.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "SFVideoEncoder.h"
#include "VideoH264Encoder.hpp"
#import "DataWriter.h"

void didCompressCallback(void*client,VideoPacket*pkt);

@implementation SFVideoEncoder
{
    VideoH264Encoder *_encoder;
    VideoParameters _params;
    DataWriter  *_fileDataWriter;
}

- (id)init
{
    if (self = [super init]) {
        _encoder = new VideoH264Encoder();
        _encoder->setEncodeCallback((__bridge void*)self,didCompressCallback);
    }
    
    return self;
}

- (void)test
{
    _encoder = new VideoH264Encoder();
}

- (void)setParameters:(VideoCodecParameter*)param
{
    if (param == NULL) {
        return;
    }
    
    VideoParameters par;
    par.setFPS(param.fps);
    par.setWidth(param.width);
    par.setHeight(param.height);
    par.setBitrate(param.bitRate);
    par.setGOPSize(param.GOP);
    par.setBFrameNum(param.maxBFrameNums);
    par.setPixelFormat(param.format);
    _params = par;
    
    _encoder->setParameters(par);
    _encoder->openEncoder();
}

- (void)encodeRawVideo:(VideoFrame*)yuvframe
{
    if (yuvframe == NULL || yuvframe->luma == NULL) {
        return;
    }
    if (!_encoder->canUseEncoder()) {
        _encoder->openEncoder();
    }
    _encoder->sendRawVideoAndReceivePacketVideo(yuvframe);
}

- (void)flushEncode
{
    NSLog(@"flushEncode");
    _encoder->flushEncoder();
    _encoder->closeEncoder();
}

- (void)closeEncoder
{
    NSLog(@"closeEncoder");
    _encoder->closeEncoder();
}

#pragma mark didCompressCallback
void didCompressCallback(void*client,VideoPacket*pkt)
{
    SFVideoEncoder *mySelf = (__bridge SFVideoEncoder*)client;
    if (mySelf.delegate.enableWriteToh264 && mySelf.delegate.h264FilePath) {
        
        if (mySelf->_fileDataWriter && ![mySelf->_fileDataWriter.savePath isEqualToString:mySelf.delegate.h264FilePath]) {
            [mySelf->_fileDataWriter deletePath];
            mySelf->_fileDataWriter = nil;
        }
        
        if (!mySelf->_fileDataWriter) {
            mySelf->_fileDataWriter = [[DataWriter alloc] initWithPath:mySelf.delegate.h264FilePath];
        }
        
        [mySelf->_fileDataWriter writeDataBytes:pkt->data len:pkt->size];
    }
    if ([mySelf.delegate respondsToSelector:@selector(didEncodeSucess:)]) {
        [mySelf.delegate didEncodeSucess:pkt];
    }
}
@end
