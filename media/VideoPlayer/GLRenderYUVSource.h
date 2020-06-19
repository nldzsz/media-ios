//
//  GLRenderYUVSource.h
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/6/5.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GLDefine.h"
#import "GLProgram.h"
#import "GLFrameBuffer.h"
#import "GLRenderSource.h"

@interface GLRenderYUVSource : GLRenderSource

// 初始化方法 context 上下文；rSize:帧缓冲区大小(单位像素)
- (id)initWithContext:(GLContext*)context
       withRenderSize:(CGSize)rSize;

// 上传纹理
- (void)loadYUVFrame:(VideoFrame*)frame;
// 渲染
- (void)renderpass;

- (void)releaseSources;
@end
