//
//  GLProgram.h
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/5/29.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GLDefine.h"

@interface GLProgram : NSObject
{
    // 由顶点着色器和片段着色器生成的程序
    GLuint  filterProgram;
}
/**
 *  根据GLSL编写的顶点着色器和片段着色器初始化；初始化完成后，最终生成的程序将作为app与glsl交
 *  互的桥梁；具体交互流程如下：
 *  1、通过glGetAttribLocation()、glGetUniformLocation()等系列函数获取glsl的变量句柄
 *  2、通过glglVertexAttribPointer()、glTexImage2D、glUniform1i()等系列函数给glsl变量设置值
 *  与opengl es交互了
 *  vString:顶点着色器
 *  fString:片段着色器
 */
- (id)initWithVertexShaderType:(NSString*)vString fragShader:(NSString*)fString;
/** 获取顶点着色器GLSL中的attribute修饰的顶点变量句柄;
 *  比如attribute vec4 position;(一般用来表示几何图元的坐标)和attribute vec2 texcoord;(一般用来表示纹理坐标)
 *  atrname:顶点着色器中由attribute修饰的变量，变量名不能以gl_开头，否则这里返回-1
 *  return:成功返回>0的整数，失败返回-1
 *
 */
- (GLint)attribLocationForName:(NSString*)atrname;
/** 获取片段着色器GLSL中的纹理句柄,app通过此句柄来设置纹理相关属性和传递图片给open gl es；
 *  比如uniform sampler2D inputImageTexture;
 *  uname:顶点着色器中由attribute修饰的变量，变量名不能以gl_开头，否则这里返回-1
 *  return:成功返回>0的整数，失败返回-1
 */
- (GLint)uniformLocationForName:(NSString*)uname;

// 让生成的最终程序处于运行状态,这样最终调用绘图指令的时候前面设置的这些参数才会真正执行
- (void)use;

- (void)destroy;
@end
