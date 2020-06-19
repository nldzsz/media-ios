//
//  GLVideoView.m
//  media
//
//  Created by 飞拍科技 on 2019/6/8.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "GLVideoView.h"
#import "GLDefine.h"
#import "GLContext.h"
#import "GLProgram.h"
#import "GLRenderYUVSource.h"

@interface GLVideoView ()
{
    GLuint _framebuffer;
    GLuint _renderbuffer;
    int _renderWidth,_renderHeight;
    CAEAGLLayer *_mylayer;
    
}
@property (strong, nonatomic)GLContext *context;
@property (strong, nonatomic)GLRenderYUVSource *yuvSource;

@end
@implementation GLVideoView
+ (Class)layerClass;
{
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        
        _mylayer = (CAEAGLLayer*)self.layer;
        self.context = [[GLContext alloc] initDefaultContextLayer:_mylayer];
        [self.context useAsCurrentContext];
        
        CGSize rSize = self.frame.size;
        _renderWidth = rSize.width * self.layer.contentsScale;
        _renderHeight = rSize.height * self.layer.contentsScale;
    }
    
    return self;
}

- (void)rendyuvFrame:(VideoFrame*)yuvFrame
{
    if (yuvFrame == NULL) {
        return;
    }
    
    // 切换上下文
    [self.context useAsCurrentContext];
    
    if (!self.yuvSource) {
        CGSize rSize = CGSizeMake(_renderWidth, _renderHeight);
        self.yuvSource = [[GLRenderYUVSource alloc] initWithContext:self.context withRenderSize:rSize];
        self.yuvSource.isOffscreenSource = NO;
    }
    
    // 上传纹理
    [self.yuvSource loadYUVFrame:yuvFrame];
    
    // 激活当前帧缓冲区
    [self setupFramebufferRenderBuffer];
    
    // 渲染
    [self.yuvSource renderpass];
    
    // 呈现到屏幕上
    [self.context presentForDisplay];
    
    
//    NSString *file  = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
//    file = [file stringByAppendingPathComponent:@"1.jpg"];
//    NSLog(@"保存路径 %@",file);
//
//    CGImageRef imgref = [self.yuvSource.outputFramebuffer newCGImageFromFramebufferContents];
//    UIImage *image = [[UIImage alloc] initWithCGImage:imgref];
//    NSData *imgData = UIImageJPEGRepresentation(image, 1.0);
//    [imgData writeToFile:file atomically:YES];
}

- (void)setupFramebufferRenderBuffer
{
    if (!_renderbuffer) {
        glGenRenderbuffers(1, &_renderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        
        GLuint framebufer = [self.yuvSource outputFramebuffer].framebuffer;
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER,framebufer);
        [self.context.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_mylayer];
    }
}

- (void)releaseSources
{
    if (self.yuvSource) {
        [self.yuvSource releaseSources];
        self.yuvSource = nil;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    
}
@end
