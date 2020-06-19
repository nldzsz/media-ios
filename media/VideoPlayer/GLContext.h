//
//  GLContext.h
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/5/29.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GLDefine.h"
#import <CoreMedia/CoreMedia.h>

/** 在ios中
 *  1、要使用Opengl es 需要引用头文件
 *  // 提供标准的opengl es接口
 *  #import <OpenGLES/ES2/gl.h>
 *  // IOS平台用于进行上下文管理及窗口管理的头文件
 *  #import <OpenGLES/EAGL.h>
 *  2、要想使用opengl es，则必须创建上下文环境
 */
@interface GLContext : NSObject
{
    CMMemoryPoolRef           _memoryPool;
    CVOpenGLESTextureCacheRef _coreVideoTextureCache;
}
// 内存缓冲池
@property (readonly)CMMemoryPoolRef memoryPool;
@property (readonly)CVOpenGLESTextureCacheRef coreVideoTextureCache;

@property (strong, nonatomic,readonly) EAGLContext *context;

// 默认opengl es 2.0 和不支持多线程
- (id)initDefaultContextLayer:(CAEAGLLayer*)caLayer;

- (id)initWithApiVersion:(EAGLRenderingAPI)version
             multiThread:(BOOL)yesOrnot
                   layer:(CAEAGLLayer*)calayer;

// 将上下文设置为当前线程的上下文环境
- (void)useAsCurrentContext;
// 释放上下文
- (void)releaseContext;

// 将帧缓冲中的像素渲染到屏幕上
- (void)presentForDisplay;

// 判断当前系统是否支持CVOpenGLESTextureCacheRef 纹理缓冲功能(改功能有助于提高视频渲染时的效率)
+ (BOOL)supportsFastTextureUpload;
+ (CGSize)sizeThatFitsWithinATextureForSize:(CGSize)inputSize;
+ (GLint)maximumTextureSizeForThisDevice;

@end
