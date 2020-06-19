//
//  SFVideoEncoder.h
//  media
//
//  Created by 飞拍科技 on 2019/7/22.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MZCommonDefine.h"
#import "VideoCodecParameter.h"
#import "CommonProtocal.h"

@interface SFVideoEncoder : NSObject<VideoEncodeProtocal>

@property(nonatomic,weak)id<VideoEncodeDelegate>delegate;

- (void)test;
@end
