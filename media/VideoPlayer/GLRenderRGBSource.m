//
//  GLRenderRGBSource.m
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/6/5.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "GLRenderRGBSource.h"

/** 遇到问题，glsl编译通不过
 *  1、void修饰main()函数
 *  2、varying 修饰的变量必须加精度修饰符 比如 highp
 */
NSString *const vString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 
 varying highp vec2 tex_coord;
 
 void main(){
     gl_Position = position;
     tex_coord = texcoord;
 }
);

// 获取一张图片的颜色
NSString *const onlyrgbString = SHADER_STRING
(
 uniform sampler2D texture;
 
 varying highp vec2 tex_coord;
 
 void main(){
     gl_FragColor = texture2D(texture,tex_coord);
 }
);

const float positions[8] = {
    -1.0,-1.0,
    1.0,-1.0,
    -1.0,1.0,
    1.0,1.0
};
const float texcoords[8] = {
    0.0,0.0,
    1.0,0.0,
    0.0,1.0,
    1.0,1.0
};
@interface GLRenderRGBSource ()
{
    // ===== 用于一张图片 ======= //
    // 用于正常的opengl es 的texture id
    GLuint _rgbTexture;
    // 保存着正常的opengl es的texutre id
//    GLuint _fastrgbTexture;
    // 用于基于CVOpenGLESTextureCacheRef的texture 对象
    CVOpenGLESTextureRef _rgbTextureRef;
    // ===== 用于一张图片 ======= //
}
// 用于获取一张图片的颜色
@property(nonatomic,strong) GLProgram *rgbProgram;

@property(nonatomic,strong) NSString *filePath;

@end
@implementation GLRenderRGBSource

- (id)initWithContext:(GLContext *)context
{
    if (self = [super initWithContext:context]) {
        self.renderWidth = 1280;
        self.renderHeight = 720;
        
        self.rgbProgram = [[GLProgram alloc] initWithVertexShaderType:vString fragShader:onlyrgbString];
        if (self.rgbProgram == nil) {
            return nil;
        }
    }
    return self;
}

/** 因为不会将渲染结果呈现到屏幕上，所以可能也不会对纹理进行压缩，纹理是多大，FBO就是多大
 */
- (void)configoutputframebuffer
{
    if (self.renderWidth != outputFramebuffer.size.width || self.renderHeight != outputFramebuffer.size.height) {
        [outputFramebuffer destroyFramebuffer];
    }
    
    CGSize size = CGSizeMake(self.renderWidth, self.renderHeight);
    outputFramebuffer = [[GLFrameBuffer alloc] initWithContext:self.context bufferSize:size offscreen:NO];
}

- (void)loadRGBPixelBuffer:(void*)buffer width:(int)width height:(int)height
{
    if (buffer == NULL) {
        return;
    }
    
    self.renderWidth = width;
    self.renderHeight = height;
    
    [self configoutputframebuffer];

    if (self.useFastupload) {
        [self loadTextureFastup:buffer width:width height:height];
    } else {
        [self loadTextureNormal:buffer width:width height:height];
    }
    
}

/* 通过opengl es的glTexImage2D()函数正常上传图片到opengl es
 */
- (void)loadTextureNormal:(void*)buf width:(int)width height:(int)height
{
    if (buf == NULL) {
        return;
    }
    
    if (_rgbTexture == 0) {
        glGenTextures(1, &_rgbTexture);
    }
    
    if (_inTextureWidth != width || _inTextureWidth != height) {
        glBindTexture(GL_TEXTURE_2D, _rgbTexture);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        // 如果这里纹理的大小发送了改变，则重新分配内存，并上传纹理;该函数每次调用都会分配内存
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, buf);
    } else {
        glBindTexture(GL_TEXTURE_2D, _rgbTexture);
        // 如果这里纹理大小没有改变，直接上传纹理，不重新分配内存，提高了效率；该函数直接使用由glTexImage2D()分配的内存
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, buf);
    }
}

void stillImageDataReleaseCallback(void *releaseRefCon, const void *baseAddress)
{
    free((void *)baseAddress);
}
/** 通过基于CVOpenGLESTextureCacheRef的texture缓冲系统上传图片到opengl es
 */
- (void)loadTextureFastup:(void*)buf width:(int)width height:(int)height
{
    if (buf == NULL) {
        return;
    }
    /** 使用指定的内存池的CFAllocatorRef对象，那么后续在使用该分配器创建对象时，获得的内存将来自于该内存池
     *  kCFAllocatorDefault 是系统默认的内存池
     */
    CFAllocatorRef allocator = CMMemoryPoolGetAllocator(self.context.memoryPool);
    /** 1、此函数只是简单的生成一个CVPixelBufferRef，该对象的有一个指向原始像素数据的地址指针，里面没有像素数据拷贝
     *  2、第四个参数指明了每个像素中RGBA分量的存储顺序，它应该与传入的原始像素数据保持一致。
     *  3、对于CVPixelBufferRef对象，它的像素格式kCVPixelFormatType_32BGRA中像素分量的存储顺序与glTexImage2D()函数中GL_RGBA顺序一样,含义是一样的
     */
    CVPixelBufferRef pixelBuffer;
    CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height,    // 最终生成的CVPixelBufferRef的宽和高
                                 kCVPixelFormatType_32BGRA,// 最终生成的CVPixelBufferRef的像素数据格式，这也是ios默认的像素数据格式
                                 buf,       //用于生成CVPixelBufferRef的原始像素数据的内存地址
                                 width*4,   //用于生成CVPixelBufferRef的原始像素数据的内存每一行的字节数
                                 stillImageDataReleaseCallback, // 一定要有，用来释放内存
                                 NULL, NULL,    // 传空就好
                                 &pixelBuffer   // 最终生成CVPixelBufferRef对象
                                 );
    // 该功能与glTexImage2D()函数功能类似
    CVReturn result = CVOpenGLESTextureCacheCreateTextureFromImage(allocator, self.context.coreVideoTextureCache,
                                pixelBuffer,    // 要加载到opengl es的CVPixelBufferRef像素对象
                                NULL, GL_TEXTURE_2D,
                                GL_RGBA,    //opengl es 内部对于该像素对象存储像素的方式,相当于glTexImage2D()函数第三个参数
                                width, height,GL_BGRA, GL_UNSIGNED_BYTE,//pixelBuffer对象的宽，高，像素格式，及每个像素分量的位宽
                                0,// 纹理和pixelBuffer像素索引的对应关系。对于planner格式的pixelBuffer(比如pixelBuffer包含YUV三个分量时,就可以分别
                                  // 用0 1 2来表示这个对应关系)
                                &_rgbTextureRef
                                );
    if (result != kCVReturnSuccess
        || _rgbTextureRef == NULL){
        NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", result);
        return;
    }
    
    _rgbTexture = CVOpenGLESTextureGetName(_rgbTextureRef);
    // 接下来就和普通的texture 一样使用了
    glBindTexture(GL_TEXTURE_2D, _rgbTexture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
}

- (void)renderPass
{
    // 1.渲染前必须先绑定FBO，这样渲染的结果将存储到该FBO中;一定要先调用glBindFramebuffer()再调用glViewport()才有效，因为它是在frame buffer的大小基础上开辟一个
    // 用于渲染的区域
    [outputFramebuffer activateFramebuffer];
    
    // 2.渲染前必须清除一下之前的颜色(好比画画之前先把画板清晰干净)
    glClearColor(0, 0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // 3.渲染前先激活着色器程序，这样渲染管线才知道用哪个GLSL程序
    [self.rgbProgram use];
    GLuint position = [self.rgbProgram attribLocationForName:@"position"];
    GLuint texcoord = [self.rgbProgram attribLocationForName:@"texcoord"];
    GLuint texture  = [self.rgbProgram uniformLocationForName:@"texture"];
    glVertexAttribPointer(position, 2, GL_FLOAT, 0, 0, positions);
    glEnableVertexAttribArray(position);
    glVertexAttribPointer(texcoord, 2, GL_FLOAT, 0, 0, texcoords);
    glEnableVertexAttribArray(texcoord);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _rgbTexture);
    glUniform1i(texture, 1);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // 调用此函数，这样渲染指令才会立即执行，否则渲染可能会延迟(因为opengl es默认机制是等到它自己的指令缓冲区满了之后才执行)
    glFlush();
    
    [self cleanupTexture];
}

- (void)cleanupTexture
{
    // 每次对调用glBindTexture()绑定的纹理类型使用完毕后，最好调用glBindTexture(GL_TEXTURE_2D, 0);进行解绑，这样在其它地方调用gltexxxx()函数才不会相互
    // 影响
    glBindTexture(GL_TEXTURE_2D, 0);
    
    /** 对于基于ios系统的CVOpenGLESTextureCacheRef的纹理缓冲系统来说，每次渲染结束还必须要释放texture 对象
     *  对于通过opengl es的glGenTexture()函数生成的texutre id则可以重复使用，不必每次glDrawArrays()后清除，这样可以提高复用率
     */
    if (_rgbTextureRef != NULL) {
        glBindTexture(CVOpenGLESTextureGetTarget(_rgbTextureRef), 0);
        CFRelease(_rgbTextureRef);
        _rgbTextureRef = NULL;
        _rgbTexture = 0;
    }
}

- (void)renderToScreen
{
    
}

- (void)dealloc
{
    if (_rgbTextureRef != NULL) {
        glBindTexture(CVOpenGLESTextureGetTarget(_rgbTextureRef), 0);
        CFRelease(_rgbTextureRef);
        _rgbTextureRef = NULL;
    }
    
    if (_rgbTexture) {
        glDeleteTextures(1, &_rgbTexture);
        _rgbTexture = 0;
    }
}
@end
