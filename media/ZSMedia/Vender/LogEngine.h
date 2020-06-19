//
//  LogEngine.h
//  media
//
//  Created by 飞拍科技 on 2019/8/14.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>

// 用于开启c++的日志功能
@interface LogEngine : NSObject
+(void)enableLog:(BOOL)enable;
@end
