//
//  GLFrameBuffer.h
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/6/5.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>
#import "GLContext.h"
#import <VideoToolbox/VideoToolbox.h>

typedef struct GLFrameBufferTextureOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} GLFrameBufferTextureOptions;

GLFrameBufferTextureOptions defaultOptionsForTexture(void);

/** 对FBO帧缓冲区的封装
 *  1、如果使用CVOpenGLESTextureCacheRef来管理texture，则不需要手动创建texture
 */
@interface GLFrameBuffer : NSObject
// 用于表示纹理的长宽
@property (nonatomic,readonly) CGSize size;
@property (nonatomic,readonly) GLContext *context;
@property (nonatomic,readonly) GLuint texture;  // 纹理id
@property (nonatomic,readonly) GLuint framebuffer;  // 帧缓冲 id
@property (nonatomic,readonly) GLFrameBufferTextureOptions textureOptions;

/** 是否离屏渲染缓冲区
 *  YES，那么会将创建的帧缓冲区与纹理绑定，渲染结果结束后渲染结果直接定位到outputFramebuffer的
 *  texture纹理中，作为离屏渲染的关键实现;帧缓冲区打次奥和纹理大小一致
 *  NO,那么只是创建一个帧缓冲区，该帧缓冲区用于与render buffer绑定，呈现到屏幕上；帧缓冲区大小和屏幕大小一致
 */
@property (assign, nonatomic,readonly) BOOL isOffscreenRender;

// 将默认创建一个1280x720大小的FBO
- (id)initDefaultBufferWithContext:(GLContext*)context offscreen:(BOOL)offscreen;
- (id)initWithContext:(GLContext*)context bufferSize:(CGSize)size offscreen:(BOOL)offscreen;
- (void)destroyFramebuffer;

- (void)activateFramebuffer;

// 将FBO中的像素数据转化成图片对象返回
- (CGImageRef)newCGImageFromFramebufferContents;
@end
