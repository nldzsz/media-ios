//
//  GLRenderRGBSource.h
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/6/5.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GLDefine.h"
#import "GLRenderSource.h"
#import "GLFrameBuffer.h"

/** 该类设计用来将z最终可以转换成RGBA格式的图片加载到纹理中，进行渲染。
 */
@interface GLRenderRGBSource : GLRenderSource
{
    // 输入纹理的宽和高
    int _inTextureWidth;
    int _inTextureHeight;
}
// 是否使用基于CVOpenGLESTextureCacheRef对象的缓存系统进行纹理上传,对于视频渲染效率比较高 默认关闭;必须在调用上传纹理函数loadxxx()之前赋值
@property (assign, nonatomic) BOOL useFastupload;

// 最终渲染的宽和高 单位像素 默认1280x720
@property (assign, nonatomic) int renderWidth;
@property (assign, nonatomic) int renderHeight;

- (id)initWithContext:(GLContext *)context;

// 从外界传递rgba像素数据过来
- (void)loadRGBPixelBuffer:(void*)buffer width:(int)width height:(int)height;

// 开始渲染(就是调用glDraws()函数),将渲染结果存储到指定的离屏FBO缓冲区
- (void)renderPass;
@end
