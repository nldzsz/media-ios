//
//  GLUtils.h
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/5/29.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GLDefine.h"

@interface GLUtils : NSObject

/** 检查当前EAGLContext中分配的frame buffer是否出错
 *  return: NO表示出错，具体出错信息在error中；YES表示分配成功
 */
+(BOOL)checkFramebuffer:(NSError *__autoreleasing *)error;


@end
