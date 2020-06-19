//
//  VideoParameters.h
//  media
//
//  Created by apple on 2019/8/24.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MZCommonDefine.h"
#import "CodecDefine.h"

@interface VideoCodecParameter : NSObject

@property (assign,nonatomic) MZPixelFormat format;
@property (assign,nonatomic) int width;
@property (assign,nonatomic) int height;
@property (assign,nonatomic) int fps;
@property (assign,nonatomic) int GOP;
@property (assign,nonatomic) int maxBFrameNums;
@property (assign,nonatomic) int bitRate;

- (id)initWithWidth:(NSInteger)width
             height:(NSInteger)height
        pixelformat:(MZPixelFormat)pixelformat
                fps:(NSInteger)fps
                gop:(NSInteger)gop
            bframes:(NSInteger)bframes
            bitrate:(NSInteger)brate;

- (OSType)cvpixelType;
@end
