//
//  ADUnitTool.h
//  media
//
//  Created by Owen on 2019/5/19.
//  Copyright © 2019 Owen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <AudioToolbox/AudioToolbox.h>

@interface ADUnitTool : NSObject

// 创建指定的组件描述
+ (AudioComponentDescription)comDesWithType:(OSType)type subType:(OSType)subType fucture:(OSType)manufuture;

/** 创建用于音频的指定的LinePCM数据流描述
 *  播放和录制：支持16位，32位整形和32位浮点型
 */
+ (AudioStreamBasicDescription)streamDesWithLinearPCMformat:(AudioFormatFlags)flags
                                                 sampleRate:(CGFloat)rate
                                                   channels:(NSInteger)chs
                                            bytesPerChannel:(NSInteger)bytesPerChannel;

+ (void)printStreamFormat:(AudioStreamBasicDescription)streamASDB;
@end
