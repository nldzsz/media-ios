//
//  Muxer.h
//  media
//
//  Created by apple on 2019/9/8.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "MZCommonDefine.h"
#import "VideoCodecParameter.h"
#import "AudioCodecParameter.h"

@interface FileMuxer : NSObject

- (instancetype)initWithPath:(NSString*)filepath;

// todo:rxz 音频参数暂未实现
- (BOOL)openMuxer;

- (void)writeVideoPacket:(VideoPacket*)packet;

- (void)writeAudioPacket;

- (void)finishWrite;
@end
