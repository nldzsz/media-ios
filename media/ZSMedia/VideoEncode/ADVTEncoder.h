//
//  ADVTEncoder.h
//  media
//
//  Created by 飞拍科技 on 2019/8/9.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import "VideoCodecParameter.h"
#import "CommonProtocal.h"
#import "DataWriter.h"

/** 对VideoToolbox中编码方式的封装
 */
@interface ADVTEncoder : NSObject<VideoEncodeProtocal>

@property(nonatomic,weak)id<VideoEncodeDelegate>delegate;

- (void)enCodeWithImageBuffer:(CVImageBufferRef)imageBuffer;
@end
