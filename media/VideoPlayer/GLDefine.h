//
//  GLDefine.h
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/5/29.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef GLDefine_h
#define GLDefine_h

#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/EAGL.h>
#import "GLProgram.h"
#import "GLContext.h"
#import "MZCommonDefine.h"

// 视频的默认帧率
#define Default_fps 24
// 每一帧时长 单位微秒
#define usec_per_fps (1000000/Default_fps)

#endif /* GLDefine_h */
