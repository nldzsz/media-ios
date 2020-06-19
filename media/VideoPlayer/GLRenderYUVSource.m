//
//  GLRenderYUVSource.m
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/6/5.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "GLRenderYUVSource.h"

/** 1、遇到问题 视频倒立
 *  解决思路：经过ffmpeg解码后的视频帧(一张图片)，它在内存中的存储是以左上角为原点进行存储的(也就与屏幕坐标系一致)
 *  但是opengl es中纹理坐标系左下角是原点,也就是上下颠倒的，所以传递时就必须按照opengl es的纹理坐标系顺序来。
 */
static float posionData[8] =
{
    -1.0,-1.0,
    1.0,-1.0,
    -1.0,1.0,
    1.0,1.0
};
static float texcoordData[8] =
{
    0.0,1.0,
    1.0,1.0,
    0.0,0.0,
    1.0,0.0
};

/** BT.709  RGB和YUV(video range、full range)转换矩阵
 *  fullRange和videoRange本身的意义是YUV颜色空间中亮度部分Y的取值范围，fullRange的取值范围为luma=[0,255]
 *  chroma=[0,255]，而videoRange是luma=[16,235] chroma=[16,240]，另外chroma(Cb,Cr)即色度部分与亮度
 *  部分不同，始终为fullRange
 */
//yuv convert mat from video range [16,235]
GLfloat _yuvTransToRBGVideoRangeMAT[] = {
    1.1644,     1.1644,     1.1644,     0.0,
    0.0,        -0.2132,    2.1124,     0.0,
    1.7927,     -0.5329,    0.0,        0.0,
    0.0,        0.0,        0.0,        1.0,
};

//for yuv data in full range 0~255
GLfloat _yuvTransToRBGFullRangeMAT[16] = {
    1.0, 1.0, 1.0, 0,
    0, -0.343, 1.765, 0,
    1.4, -0.711, 0, 0,
    0, 0, 0, 1
};

NSString *const yuvVS = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 
 varying highp vec2 v_texcoord;
 void main(){
     gl_Position = position;
     v_texcoord = texcoord;
 }
);

/** YUV转换成RGB后并再与一个系数相乘(用来做简单的颜色滤镜，该系数默认为1，不做滤镜)
 *  YUV转换成RGB为 BT709标准
 *  yuvToRGBmatrix 为转换矩阵，即如下中的M
 *  依据为 [RGB] = [M]([YUV] + [xyz]),其中M为前面指定的转换矩阵，[YUVA]为应用端传递的YUV志量化为(0-1)
 *  范围的矩阵
 *  [xyz] 则是RGB与YUV转化的偏移系数矩阵，分两种情况:
 *  对于video range:[-0.0627451,-0.5,-0.5] 对应的公式为：
 *  对于full range:[0,-0.5,-0.5]
 *  luminanceScale为(xyz) x为上面[xyzw]偏移系数矩阵的x，对于video range和full range视频取值不一样;y为转换
 *  成RGB后乘以的一个系数,默认为1(如果为0.5，则将YUV转换成RGB后再对RGB每个分量乘以0.5),zw为0
 */
NSString *const yuvcolorFS = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 
 uniform sampler2D texture_y;
 uniform sampler2D texture_u;
 uniform sampler2D texture_v;
 
 uniform highp mat4 yuvToRGBmatrix;
 uniform highp vec4 luminanceScale;
 void main(){
    highp vec4 color_yuv = vec4(texture2D(texture_y,v_texcoord).r + luminanceScale.x,
                                texture2D(texture_u,v_texcoord).r - 0.5,
                                texture2D(texture_v,v_texcoord).r - 0.5,
                                1.0)*luminanceScale.y;
    highp vec4 color_rgb = yuvToRGBmatrix * color_yuv;
     gl_FragColor = color_rgb;
 }
);

@interface GLRenderYUVSource ()
{
    // 绑定对应yuv纹理的 texutre id
    GLuint textureyuvs[3];
    
    // 基于CVOpenGLESTextureCacheRef时对应的纹理
    CVOpenGLESTextureRef cvtextureyuvs[3];
    
    // 上一次输入纹理的宽和高，当要渲染的纹理的宽和高改变时，就需要重新通过glTexImage2D()函数分配内存了
    int _lastInTexWidth,_lastIntexHeight;
    // 渲染区域的宽和高，和纹理的宽高不一定相同
    int _renderWidth,_renderHeight;
    
    // 着色器中变量地址
    GLuint _samplers[3];
    GLuint _postion;
    GLuint _texcoord;
    GLuint _yuvtorgbmaxtric;
    GLuint _luminanceScalemaxtric;
    
    // 是否full range
    BOOL isfullrange;
}
@property (strong, nonatomic) GLProgram *yuvprogram;
@end
@implementation GLRenderYUVSource

- (id)initWithContext:(GLContext *)context withRenderSize:(CGSize)rSize
{
    if (self = [super init]) {
        self.context = context;
        
        _lastInTexWidth = 1280;
        _lastIntexHeight = 720;
        _renderWidth = rSize.width;
        _renderHeight = rSize.height;
    }
    
    return self;
}

- (void)loadYUVFrame:(VideoFrame *)frame
{
    if (frame == NULL) {
        NSLog(@"VideoFrame is NULL");
        return;
    }
    
    // 有可能播放的过程中 视频帧的分辨率改变了，那么这时候需要重新配置渲染缓冲区的大小
    [self configOutputFramebuffer];
    
    if (frame->cv_pixelbuffer != NULL) {  // 基于CVOpenGLESTextureCacheRef的纹理缓冲系统上传纹理
        [self loadTextureByFastup:frame];
    } else {   // 基于传统opengl es的纹理texture上传纹理
        [self loadTextureNormal:frame];
    }
}

- (void)configOutputFramebuffer
{
    if (self.isOffscreenSource) {
        if (_renderWidth != _lastInTexWidth || _renderHeight != _lastIntexHeight) {
            [outputFramebuffer destroyFramebuffer];
            
            CGSize newSize = CGSizeMake(_renderWidth, _renderHeight);
            outputFramebuffer = [[GLFrameBuffer alloc] initWithContext:self.context bufferSize:newSize offscreen:NO];
        }
    } else {
        if (outputFramebuffer == nil) {
            CGSize newSize = CGSizeMake(_renderWidth, _renderHeight);
            outputFramebuffer = [[GLFrameBuffer alloc] initWithContext:self.context bufferSize:newSize offscreen:NO];
        }
    }
}

- (void)loadTextureNormal:(VideoFrame*)frame
{
    BOOL hasGenTexutre = YES;
    // texture id不用重复生成，可以复用
    if (textureyuvs[0] == 0 || _lastInTexWidth != frame->width || _lastIntexHeight != frame->height) {
        
        if (textureyuvs[0] != 0) {
            glDeleteTextures(3, textureyuvs);
        }
        
        glGenTextures(3, textureyuvs);
        hasGenTexutre = NO;
        _lastInTexWidth = frame->width;
        _lastIntexHeight = frame->height;
    }
    
    for (int i=0; i<3; i++) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, textureyuvs[i]);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        /**
         *  glTexSubImage2D与glTexImage2D区别就是：
         *  前者不会创建用于传输纹理图片的内存，直接使用由glTexImage2D创建的内存，这样避免了内存的重复创建。
         */
        if (!hasGenTexutre) {
            if (i == 0) {
                glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, frame->width, frame->height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, frame->luma);
            } else if (i==1) {
                glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, frame->width/2, frame->height/2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, frame->chromaB);
            } else {
                glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, frame->width/2, frame->height/2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, frame->chromaR);
            }
        } else {
            if (i == 0) {
                glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, frame->width, frame->height, GL_LUMINANCE, GL_UNSIGNED_BYTE, frame->luma);
            } else if (i==1) {
                glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, frame->width/2, frame->height/2, GL_LUMINANCE, GL_UNSIGNED_BYTE, frame->chromaB);
            } else {
                glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, frame->width/2, frame->height/2, GL_LUMINANCE, GL_UNSIGNED_BYTE, frame->chromaR);
            }
        }
    }
    
}

- (void)loadTextureByFastup:(VideoFrame*)frame
{
    
}

- (void)renderpass
{
    // 渲染之前重新绑定渲染缓冲区
    [outputFramebuffer activateFramebuffer];
    
    //clear
    glClearColor(0.0f, 1.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    [self activeCurrentProgram];
    
    glVertexAttribPointer(_postion, 2, GL_FLOAT, 0, 0, posionData);
    glEnableVertexAttribArray(_postion);
    glVertexAttribPointer(_texcoord, 2, GL_FLOAT, 0, 0, texcoordData);
    glEnableVertexAttribArray(_texcoord);
    
    GLfloat *yuvtorgbmaxtics = _yuvTransToRBGVideoRangeMAT;
    GLfloat yoffset = 0;
    if (isfullrange) {
        yuvtorgbmaxtics = _yuvTransToRBGFullRangeMAT;
    } else {
        yoffset = -(GLfloat)16/255;
    }
    
    for (int i=0; i<3; i++) {
        glActiveTexture(GL_TEXTURE0+i);
        glBindTexture(GL_TEXTURE_2D, textureyuvs[i]);
        glUniform1i(_samplers[i], i);
    }
    
    glUniformMatrix4fv(_yuvtorgbmaxtric, 1, GL_FALSE, yuvtorgbmaxtics);
    glUniform4f(_luminanceScalemaxtric, yoffset, 1.0, 0, 0);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
//    [self cleanuptexture];
}

- (void)activeCurrentProgram
{
    if (!self.yuvprogram) {
        self.yuvprogram = [[GLProgram alloc] initWithVertexShaderType:yuvVS fragShader:yuvcolorFS];
    }
    
    [self.yuvprogram use];
    
    if (_postion == 0) {
        _postion = [self.yuvprogram attribLocationForName:@"position"];
        _texcoord = [self.yuvprogram attribLocationForName:@"texcoord"];
        GLuint tex_y = [self.yuvprogram uniformLocationForName:@"texture_y"];
        GLuint tex_u = [self.yuvprogram uniformLocationForName:@"texture_u"];
        GLuint tex_v = [self.yuvprogram uniformLocationForName:@"texture_v"];
        _samplers[0] = tex_y;
        _samplers[1] = tex_u;
        _samplers[2] = tex_v;
        _yuvtorgbmaxtric = [self.yuvprogram uniformLocationForName:@"yuvToRGBmatrix"];
        _luminanceScalemaxtric = [self.yuvprogram uniformLocationForName:@"luminanceScale"];
    }
}

- (void)cleanuptexture
{
    glBindTexture(GL_TEXTURE_2D, 0);
}


- (void)releaseSources
{
    if (textureyuvs[0] != 0) {
        glDeleteTextures(3, textureyuvs);
    }
    
    [self cleanuptexture];
    [self destroy];
}
@end
