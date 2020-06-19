//
//  GLProgram.m
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/5/29.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "GLProgram.h"

@implementation GLProgram

- (id)initWithVertexShaderType:(NSString*)vString fragShader:(NSString*)fString;
{
    if (self = [super init]) {
        GLuint vShader=0,fShader=0;
        if(![self compileShader:GL_VERTEX_SHADER sString:vString shader:&vShader]){
            return nil;
        }
        if(![self compileShader:GL_FRAGMENT_SHADER sString:fString shader:&fShader]){
            return nil;
        }
        
        // 创建一个最终程序句柄；它由顶点着色器和片段着色器组成
        filterProgram = glCreateProgram();
        // 分别添加顶点着色器程序和片段着色器程序
        glAttachShader(filterProgram, vShader);
        glAttachShader(filterProgram, fShader);
        
        /** 连接成一个最终程序
         *  当这一步完成之后，app就可以和opengl es进行交互了，
         *  1、比如app获取glsl中的顶点变量，设置几何图元的顶点以确定图元的最终形状
         *  2、app获取glsl中的纹理变量，然后将本地图片传递给这个纹理变量以实现将图片传递给显卡进行渲染和其
         *  它处理
         */
        glLinkProgram(filterProgram);
        
        // 输出连接过程中的日志
        GLint status;
        glValidateProgram(filterProgram);
#ifdef DEBUG
        GLint logLength;
        glGetProgramiv(filterProgram, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0){
            GLchar *log = (GLchar *)malloc(logLength);
            glGetProgramInfoLog(filterProgram, logLength, &logLength, log);
            NSLog(@"Program validate log:\n%s", log);
            free(log);
        }
#endif
        
        // 检查连接结果
        glGetProgramiv(filterProgram, GL_LINK_STATUS, &status);
        if (status == GL_FALSE) {
            NSLog(@"link program fail %d",status);
            return nil;
        }
        
    }
    return self;
}

- (BOOL)compileShader:(GLenum)type sString:(NSString*)sString shader:(GLuint*)shaderRet
{
    if (sString.length == 0) {
        NSLog(@"着色器程序不能为nil");
        return NO;
    }
    
    const GLchar *sources = (GLchar*)[sString UTF8String];
    
    // 创建着色器程序句柄
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        NSLog(@"glCreateShader fail");
        return NO;
    }
    
    // 为着色器句柄添加GLSL代码;可一次添加多个代码，一般添加一个，若添加一个源代码则最后一个参数为NULL 即可
    glShaderSource(shader, 1, &sources, NULL);
    // 编译该GLSL代码
    glCompileShader(shader);
    
    // 打印出编译过程中产生的GLSL的日志
#ifdef DEBUG
    GLint logLenght;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLenght);
    if (logLenght > 0) {
        GLchar *log = (GLchar*)malloc(logLenght);
        glGetShaderInfoLog(shader, logLenght, &logLenght, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    // 检查编译结果
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"compile fail %d",status);
        return NO;
    }
    
    *shaderRet = shader;
    return YES;
}

/** 获取顶点着色器GLSL中的attribute修饰的顶点变量句柄;
 *  比如attribute vec4 position;(一般用来表示几何图元的坐标)和attribute vec2 texcoord;(一般用来表示纹理坐标)
 */
- (GLint)attribLocationForName:(NSString*)atrname
{
    if (filterProgram == 0 || atrname.length == 0) {
        return -1;
    }
    
    // 返回指定变量的地址句柄，如果atrname以gl_开头或者filterProgram还未link，或者该变量不存在，返回-1
    return glGetAttribLocation(filterProgram, [atrname UTF8String]);
}
/** 获取片段着色器GLSL中的纹理句柄,app通过此句柄来设置纹理相关属性和传递图片给open gl es；
 *  比如uniform sampler2D inputImageTexture;
 */
- (GLint)uniformLocationForName:(NSString*)uname
{
    
    if (filterProgram == 0 || uname.length == 0) {
        return -1;
    }
    
    return glGetUniformLocation(filterProgram, [uname UTF8String]);
}

- (void)use
{
    if (filterProgram == 0) {
        return;
    }
    
    glUseProgram(filterProgram);
}

- (void)destroy
{
    if (filterProgram != 0) {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
}
@end
