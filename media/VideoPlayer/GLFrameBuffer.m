//
//  GLFrameBuffer.m
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/6/5.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "GLFrameBuffer.h"

GLFrameBufferTextureOptions defaultOptionsForTexture(){
    GLFrameBufferTextureOptions defaultTextureOptions = {0};
    defaultTextureOptions.minFilter = GL_LINEAR;
    defaultTextureOptions.magFilter = GL_LINEAR;
    defaultTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultTextureOptions.internalFormat = GL_RGBA;
    defaultTextureOptions.format = GL_BGRA;
    defaultTextureOptions.type = GL_UNSIGNED_BYTE;
    
    return defaultTextureOptions;
};

@interface GLFrameBuffer(){
    GLuint framebuffer;
    CVPixelBufferRef renderTarget;
    CVOpenGLESTextureRef renderTexture;
    NSUInteger readLockCount;
    NSUInteger framebufferReferenceCount;
    BOOL referenceCountingDisabled;
}
@end

@implementation GLFrameBuffer
@synthesize size = _size;
@synthesize textureOptions = _textureOptions;
@synthesize texture = _texture;
@synthesize framebuffer = framebuffer;

- (id)initDefaultBufferWithContext:(GLContext*)context offscreen:(BOOL)offscreen
{
    return [self initWithContext:context bufferSize:CGSizeMake(1280, 720) offscreen:offscreen];
}

- (id)initWithContext:(GLContext *)context bufferSize:(CGSize)size offscreen:(BOOL)offscreen
{
    if (self = [super init]) {
        _size = size;
        _context = context;
        _textureOptions = defaultOptionsForTexture();
        _isOffscreenRender = offscreen;
        [self generateFrameBuffer];
    }
    return self;
}

- (void)generateTexture
{
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &_texture);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, _textureOptions.minFilter);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, _textureOptions.magFilter);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);
}

- (void)generateFrameBuffer
{
    // 在绑定frambufer钱要调用该函数，将GL ES上下文切换到当前线程，否则会奔溃
    [_context useAsCurrentContext];
    
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    if (!self.isOffscreenRender) {
        NSLog(@"非离屏渲染FBO,直接返回");
        return;
    }
    
    if ([GLContext supportsFastTextureUpload]) {
        CVOpenGLESTextureCacheRef textureCache = [_context coreVideoTextureCache];
        // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/
        CFDictionaryRef empty;
        CFMutableDictionaryRef attrs;
        empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
        /** CVPixelBufferCreate()两个函数作用相当于
         *  kCVPixelFormatType_32BGRA:相当于glTexImage2D()倒数第三个参数，定义像素数据的格式
         *  attrs:定义纹理的其它属性
         *  renderTarget:最终将生成一个CVPixelBufferRef类型的像素块，默认值为0，相当于void *pixbuffer = (void*)malloc(size);
         *  最终将根据传入参数，宽、高，像素格式，和属性生成一个用于存储像素的内存块
         */
        CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, (size_t)_size.width, (size_t)_size.height, kCVPixelFormatType_32BGRA, attrs, &renderTarget);
        if (err) {
            NSLog(@"FBO size: %f, %f", _size.width, _size.height);
            NSAssert(NO, @"Error at CVPixelBufferCreate %d", err);
        }
        
        /** 该函数有两个作用：
         *  1、renderTarget像素数据传给opengl es，类似于相当于glTexImage2D()，当然renderTarget中数据可以是由CVPixelBufferCreate()创建的默认值都是
         *  0的像素数据，也可以是具体的像素数据
         *  2、生成对应格式的CVOpenGLESTextureRef对象(相当于glGenTextures()生成的texture id)
         *  CVOpenGLESTextureRef对象(它是对Opengl es中由glGenTextures()生成的texture id的封装)
         */
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                            textureCache,
                            renderTarget,
                            NULL, // texture attributes
                            GL_TEXTURE_2D,
                            _textureOptions.internalFormat, // opengl format，相当于glTexImage2D()函数第三个参数
                            (int)_size.width,(int)_size.height,
                            _textureOptions.format, // native iOS format，相当于glTexImage2D()函数倒数第三个参数，这里即renderTarget的像素格式，这里是IOS系统默认的BGRA数据格式
                            _textureOptions.type,// 相当于glTexImage2D()函数第二个参数
                            0,// 对于planner存储方式的像素数据，这里填写对应的索引。非planner格式写0即可
                            &renderTexture);// 生成texture id
        if (err){
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        CFRelease(attrs);
        CFRelease(empty);
        
        // 那么接下来的使用就和普通的opengl es流程一样了;
        glBindTexture(CVOpenGLESTextureGetTarget(renderTexture), CVOpenGLESTextureGetName(renderTexture));
        // 由CVOpenGLESTextureCacheRef方式来管理纹理，则通过此方法来获取texture id；
        _texture = CVOpenGLESTextureGetName(renderTexture);
        
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, _textureOptions.minFilter);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, _textureOptions.magFilter);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, _textureOptions.wrapS);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, _textureOptions.wrapT);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture, 0);
    } else {
        
        [self generateTexture];
        
        glBindTexture(GL_TEXTURE_2D, _texture);
        
        // 分配指定格式的一个像素内存块，但是像素数据都初始化为0。
        glTexImage2D(GL_TEXTURE_2D, 0, _textureOptions.internalFormat, (int)_size.width, (int)_size.height, 0, _textureOptions.format, _textureOptions.type, 0);
        
        /** 此函数的意思就是将当前framebuffer中的渲染结果转换成纹理数据定位到_texture中，那么_texture就是一个已经带有像素数据的纹理对象了(即不需要经过
         *  应用端通过glTexImage2D()函数来赋值了),那么它就可以直接作为其它着色器程序中uniform sampler2D 类型的输入了，通过如下流程：
         *  glUseProgram(otherProgramHandle);       // 其它着色器程序句柄
         *  glGenFramebuffers(1, &otherframebuffer);    // otherframebuffer就是其它着色器程序对应的frame buffer
         *  glBindFramebuffer(GL_FRAMEBUFFER, otherframebuffer);
         *  glActiveTexture(GL_TEXTUREi)    // 这里的i不一定要与前面[self generateTexture]中调用的相同
         *  glBindTexture(GL_TEXTURE_2D, texture); // texutre就是这里生成的_texture，两者一定要相同
         *  glUniform1i(_uniformPresentSampler, i);
         *  .....           // 其它程序
         *  glxxx()
         *  glDrawsArrays();
         *  这段程序将以_texture中所对应的渲染结果作为纹理输入，重新开始渲染流程，期间会用指定的色器程序otherProgramHandle进行处理，最后将渲染的结果保存到
         *  新的帧缓冲区otherframebuffer中，这就是实现离屏渲染的使用流程；多次离屏渲染则依次类推
         *  此函数是实现多次离屏渲染的关键函数
         **/
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _texture, 0);
    }
    
#ifndef NS_BLOCK_ASSERTIONS
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);
#endif
    
    // 前面_texture各项参数都设置好了，那么这里可以解绑了。否则如果其它地方不小心对GL_TEXTURE_2D设置值的时候会覆盖这里的设置
    glBindTexture(GL_TEXTURE_2D, 0);
}

- (void)destroyFramebuffer;
{
    [_context useAsCurrentContext];
    
    if (framebuffer)
    {
        glDeleteFramebuffers(1, &framebuffer);
        framebuffer = 0;
    }
    
    // CVOpenGLESTextureCacheRef 中texture的释放方式
    if ([GLContext supportsFastTextureUpload])
    {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        if (renderTarget)
        {
            CFRelease(renderTarget);
            renderTarget = NULL;
        }
        
        if (renderTexture)
        {
            CFRelease(renderTexture);
            renderTexture = NULL;
        }
#endif
    }
    else
    {
        glDeleteTextures(1, &_texture);
    }
}

#pragma mark -
#pragma mark Usage
- (void)activateFramebuffer;
{
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glViewport(0, 0, (int)_size.width, (int)_size.height);
}

#pragma mark -
#pragma mark Image capture
// 用于传统glReadPixels()方式读取完成后的回调
void gl_dataProviderReleaseCallback (void *info, const void *data, size_t size)
{
    free((void *)data);
}
// 用于CVOpenGLESTextureCacheRef读取完成后的回调
void gl_dataProviderUnlockCallback (void *info, const void *data, size_t size)
{
    GLFrameBuffer *framebuffer = (__bridge_transfer GLFrameBuffer*)info;
    
    [framebuffer restoreRenderTarget];
}

// 从指定的frame buffer中读取出像素数据并转换成CGImageRef 返回(即实现截屏功能)
// 这里CVOpenGLESTextureCacheRef实现方式和传统opengl es实现方式也不一样
- (CGImageRef)newCGImageFromFramebufferContents;
{
    // a CGImage can only be created from a 'normal' color texture
    NSAssert(self.textureOptions.internalFormat == GL_RGBA, @"For conversion to a CGImage the output texture format for this filter must be GL_RGBA.");
    NSAssert(self.textureOptions.type == GL_UNSIGNED_BYTE, @"For conversion to a CGImage the type of the output texture of this filter must be GL_UNSIGNED_BYTE.");
    
    __block CGImageRef cgImageFromBytes;
    
    [_context useAsCurrentContext];
    
    NSUInteger totalBytesForImage = (int)_size.width * (int)_size.height * 4;
    // It appears that the width of a texture must be padded out to be a multiple of 8 (32 bytes) if reading from it using a texture cache
    
    GLubyte *rawImagePixels;
    
    // fastup 方式读取的图片有问题
    // 读取像素数据，并转换成能生成CGImageRef对象的CGDataProviderRef对象
    CGDataProviderRef dataProvider = NULL;
    if (false){
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        VTCreateCGImageFromCVPixelBuffer(renderTarget, NULL, &cgImageFromBytes);
        NSUInteger paddedWidthOfImage = CVPixelBufferGetBytesPerRow(renderTarget) / 4.0;
        NSUInteger paddedBytesForImage = paddedWidthOfImage * (int)_size.height * 4;
        
        glFinish();
        CFRetain(renderTarget); // I need to retain the pixel buffer here and release in the data source callback to prevent its bytes from being prematurely deallocated during a photo write operation
        [self lockForReading];
        rawImagePixels = (GLubyte *)CVPixelBufferGetBaseAddress(renderTarget);
        dataProvider = CGDataProviderCreateWithData((__bridge_retained void*)self, rawImagePixels, paddedBytesForImage, gl_dataProviderUnlockCallback);
#else
#endif
    }
    else {
        // 读取之前也要先将状态切换到当前的frame buffer中
        [self activateFramebuffer];
        rawImagePixels = (GLubyte *)malloc(totalBytesForImage);
        glReadPixels(0, 0, (int)_size.width, (int)_size.height, GL_RGBA, GL_UNSIGNED_BYTE, rawImagePixels);
        dataProvider = CGDataProviderCreateWithData(NULL, rawImagePixels, totalBytesForImage, gl_dataProviderReleaseCallback);
    }
    
    CGColorSpaceRef defaultRGBColorSpace = CGColorSpaceCreateDeviceRGB();
    // 根据CGDataProviderRef对象生成CGImageRef对象
    if (false)
    {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        cgImageFromBytes = CGImageCreate((int)_size.width, (int)_size.height, 8, 32, CVPixelBufferGetBytesPerRow(renderTarget), defaultRGBColorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst, dataProvider, NULL, NO, kCGRenderingIntentDefault);
#else
#endif
    }
    else
    {
        cgImageFromBytes = CGImageCreate((int)_size.width, (int)_size.height, 8, 32, 4 * (int)_size.width, defaultRGBColorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaNoneSkipLast, dataProvider, NULL, NO, kCGRenderingIntentDefault);
    }
    
    // Capture image with current device orientation
    CGDataProviderRelease(dataProvider);
    CGColorSpaceRelease(defaultRGBColorSpace);
    
    return cgImageFromBytes;
}

- (void)restoreRenderTarget;
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    [self unlockAfterReading];
    CFRelease(renderTarget);
#else
#endif
}

#pragma mark -
#pragma mark Raw data bytes

- (void)lockForReading
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    if ([GLContext supportsFastTextureUpload])
    {
        if (readLockCount == 0)
        {
            CVPixelBufferLockBaseAddress(renderTarget, 0);
        }
        readLockCount++;
    }
#endif
}

- (void)unlockAfterReading
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    if ([GLContext supportsFastTextureUpload])
    {
        NSAssert(readLockCount > 0, @"Unbalanced call to -[GPUImageFramebuffer unlockAfterReading]");
        readLockCount--;
        if (readLockCount == 0)
        {
            CVPixelBufferUnlockBaseAddress(renderTarget, 0);
        }
    }
#endif
}

- (NSUInteger)bytesPerRow;
{
    if ([GLContext supportsFastTextureUpload])
    {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        return CVPixelBufferGetBytesPerRow(renderTarget);
#else
        return _size.width * 4; // TODO: do more with this on the non-texture-cache side
#endif
    }
    else
    {
        return _size.width * 4;
    }
}

- (GLubyte *)byteBuffer;
{
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
    [self lockForReading];
    GLubyte * bufferBytes = (GLubyte *)CVPixelBufferGetBaseAddress(renderTarget);
    [self unlockAfterReading];
    return bufferBytes;
#else
    return NULL; // TODO: do more with this on the non-texture-cache side
#endif
}

- (GLuint)texture;
{
    //    NSLog(@"Accessing texture: %d from FB: %@", _texture, self);
    return _texture;
}

- (CVPixelBufferRef)privateRenderTarget{
    if (![GLContext supportsFastTextureUpload]){
        return NULL;
    }
    return renderTarget;
}
@end
