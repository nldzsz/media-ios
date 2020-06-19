//
//  GLContext.m
//  OpenGLES-ios
//
//  Created by 飞拍科技 on 2019/5/29.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#import "GLContext.h"

@implementation GLContext

- (id)initDefaultContextLayer:(CAEAGLLayer*)caLayer
{
    return [self initWithApiVersion:kEAGLRenderingAPIOpenGLES2 multiThread:NO layer:caLayer];
}

- (id)initWithApiVersion:(EAGLRenderingAPI)version multiThread:(BOOL)yesOrnot layer:(CAEAGLLayer*)calayer
{
    if (self = [super init]) {
        
        calayer.opaque = NO; //CALayer默认是透明的，透明的对性能负荷大，故将其关闭
        // 表示屏幕的scale，默认为1；会影响后面renderbufferStorage创建的renderbuffer的长宽值；
        // 它的长宽值等于=layer所在视图的逻辑长宽*contentsScale
        // 最好这样设置，否则后面按照纹理的实际像素渲染，会造成图片被放大。
        calayer.contentsScale = [UIScreen mainScreen].scale;
        calayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                      // 由应用层来进行内存管理
                                      @(NO),kEAGLDrawablePropertyRetainedBacking,
                                      kEAGLColorFormatRGBA8,kEAGLDrawablePropertyColorFormat,
                                      nil];

        
        // 创建指定OpenGL ES的版本的上下文，一般选择2.0的版本
        _context = [[EAGLContext alloc] initWithAPI:version];
        // 当为yes的时候，所有关于Opengl渲染，指令真正执行都在另外的线程中。NO，则关于渲染，指令真正执行在当前调用的线程
        // 对于多核设备有大的性能提升
        _context.multiThreaded = yesOrnot;
        
        _memoryPool = CMMemoryPoolCreate(NULL);
        // 收到内存不足警告后，需要清除部分内存
        __unsafe_unretained __typeof__ (self) weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *notification) {
                                                          __typeof__ (self) strongSelf = weakSelf;
                                                          if (strongSelf) {
                                                              CVOpenGLESTextureCacheFlush([strongSelf coreVideoTextureCache], 0);
                                                          }
                                                      }];
    }
    
    return self;
}

- (void)dealloc
{
    // 需要手动管理内存，这里需要手动释放内存池中的内存
    if (_memoryPool) {
        CMMemoryPoolInvalidate(_memoryPool);
        CFRelease(_memoryPool);
        _memoryPool = NULL;
    }
}
- (void)useAsCurrentContext
{
    if (!_context) {
        return;
    }
    [EAGLContext setCurrentContext:_context];
}

- (void)releaseContext
{
    if (_memoryPool) {
        CMMemoryPoolInvalidate(_memoryPool);
        CFRelease(_memoryPool);
        _memoryPool = NULL;
    }
}

- (void)presentForDisplay
{
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}
#pragma mark -
#pragma mark Manage fast texture upload
+ (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
    
#endif
}

+ (GLint)maximumTextureSizeForThisDevice;
{
    static dispatch_once_t pred;
    static GLint maxTextureSize = 0;
    
    dispatch_once(&pred, ^{
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTextureSize);
    });
    
    return maxTextureSize;
}

/** opengl es能够渲染的最大纹理长/宽 有一个最大值，如果超过这个最大值，opengl es将不能正常工作,所以超过后就必须得先对纹理
 *  压缩后在进行渲染
 */
+ (CGSize)sizeThatFitsWithinATextureForSize:(CGSize)inputSize;
{
    GLint maxTextureSize = [self maximumTextureSizeForThisDevice];
    if ( (inputSize.width < maxTextureSize) && (inputSize.height < maxTextureSize) )
    {
        return inputSize;
    }
    
    CGSize adjustedSize;
    if (inputSize.width > inputSize.height)
    {
        adjustedSize.width = (CGFloat)maxTextureSize;
        adjustedSize.height = ((CGFloat)maxTextureSize / inputSize.width) * inputSize.height;
    }
    else
    {
        adjustedSize.height = (CGFloat)maxTextureSize;
        adjustedSize.width = ((CGFloat)maxTextureSize / inputSize.height) * inputSize.width;
    }
    
    return adjustedSize;
}

/** CVOpenGLESTextureCacheRef 位于<CoreVideo/CoreVideo.h>中，专门用来处于视频纹理渲染的高效纹理缓冲区
 *  它配合CMMemoryPoolRef使用，将创建一个纹理缓冲区。
 *  工作原理就是创建一块专门用于存放纹理的缓冲区(由CMMemoryPoolRef负责管理)，这样每次应用端传递
 *  纹理像素数据给GPU时，直接使用这个缓冲区中的内存，而不用重新创建。避免了重复创建，提高了效率
 *  使用步骤如下：
 *  CFAllocatorRef allcator = CMMemoryPoolGetAllocator(context.memoryPool);
 *  CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(....)
 *              coreVideoTextureCache,  //CVOpenGLESTextureCacheRef 对象
 *              ...                     // 其它参数
 *              &fastuploadCVTexture    // 纹理对象
 *              )
 *  fastuploadCVTexture就和正常的Opengl es中由glGenTextures()函数生成的texture一样使用了
 *  这套缓存区管理系统再收到内存不够的警告时还需要有一定的自动清理机制，通过调用
 *  CVOpenGLESTextureCacheFlush()函数实现，该函数将自动减少缓冲区中的内存
 */
- (CVOpenGLESTextureCacheRef)coreVideoTextureCache
{
    if (_coreVideoTextureCache == NULL) {
        CVReturn result = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_coreVideoTextureCache);
        if (result != kCVReturnSuccess) {
            NSLog(@"CVOpenGLESTextureCacheCreate fail %d",result);
        }
    }
    
    return _coreVideoTextureCache;
}
@end
