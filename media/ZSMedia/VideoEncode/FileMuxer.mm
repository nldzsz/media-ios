//
//  Muxer.m
//  media
//
//  Created by apple on 2019/9/8.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "FileMuxer.h"
#include "Muxer.hpp"
using namespace std;

@implementation FileMuxer
{
    NSString *_savepath;
    Muxer   *_muxer;
}

- (instancetype)initWithPath:(NSString*)filepath
{
    if (self = [super init]) {
        
        NSAssert(filepath !=nil, @"存储路径不能为空");
        _savepath = filepath;
    }
    
    return self;
}

- (BOOL)openMuxer
{
    if (_muxer) {
        return YES;
    }
    
    _muxer = new Muxer([_savepath UTF8String]);
    return _muxer->openMuxer()?YES:NO;
}

- (void)writeVideoPacket:(VideoPacket *)packet
{
    if (_muxer) {
        _muxer->writeVideoPacket(packet);
    }
}

- (void)writeAudioPacket
{
    
}

- (void)finishWrite
{
    if (_muxer) {
        _muxer->closeMuxer();
        delete _muxer;
        _muxer = NULL;
    }
}

@end
