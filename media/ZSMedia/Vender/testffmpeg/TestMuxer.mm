//
//  TestMuxer.m
//  media
//
//  Created by apple on 2019/9/6.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "TestMuxer.h"
#import "Muxer.hpp"

@implementation TestMuxer

int readVideoPacket(void* client,uint8_t*buf,int bufsize)
{
    LOGD("readVideoPacket .....");
    
    return 100;
}
+ (void)testMuxer
{
    
}
@end
