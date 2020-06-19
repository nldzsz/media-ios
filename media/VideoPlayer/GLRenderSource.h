//
//  GLRenderSource.h
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/6/5.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GLUtils.h"
#import "GLProgram.h"
#import "GLContext.h"
#import "GLDefine.h"
#import "GLFrameBuffer.h"

@protocol GLRenderSourceInput <NSObject>

- (void)renderFinishAtBuffer:(GLFrameBuffer*)outputFramebuffer;
@end

/** 该类是对纹理上传，渲染流程的封装；
 *  1、它设计为一个链表;
 *  2、它的工作流程就是首先对数据进行处理，渲染完成后，交给链表中下一个处理节点继续进行
 *  3、实现多次离屏渲染的关键类
 *  4、对于ios自带的CVOpenGLESTextureCacheRef和传统的opengl es texutre方式及纹理的数据类型交由子类具体实现
 *  5、它也可以与Render buffer绑定，直接渲染到屏幕上
 */
@interface GLRenderSource : NSObject
{
    // 渲染的结果存储在该buffer中，该buffer可以作为其它渲染的输入
    GLFrameBuffer *outputFramebuffer;
    // 数组，存储下一个渲染节点
    NSMutableArray *renderTargets;
}
@property (strong, nonatomic) GLContext *context;
@property (assign, nonatomic) BOOL isOffscreenSource;

- (id)initWithContext:(GLContext*)context;

- (void)addTarget:(id<GLRenderSourceInput>)source;
- (void)removeAllTargets;
- (void)destroy;

// 绘制结束后，通知下一个节点处理，不绘制到屏幕上
- (void)notifyRenderFinish;

// 清除output frame buffer
- (void)removeOutputframebuffer;
- (GLFrameBuffer*)outputFramebuffer;

@end
