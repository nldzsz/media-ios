//
//  LogEngine.m
//  media
//
//  Created by 飞拍科技 on 2019/8/14.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "LogEngine.h"
#import "CLog.h"

@implementation LogEngine

+(void)enableLog:(BOOL)enable
{
    if (enable) {
        enableDebug();
    } else {
        disableDebug();
    }
}
@end
