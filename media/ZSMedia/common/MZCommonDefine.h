//
//  MZCommonDefine.h
//  media
//
//  Created by 飞拍科技 on 2019/8/14.
//  Copyright © 2019 飞拍科技. All rights reserved.
//

#ifndef MZCommonDefine_h
#define MZCommonDefine_h

// 宏定义
#define CP_YUV(dst, src, linesize, width, height) \
do{ \
if(dst == NULL || src == NULL || linesize < width || width <= 0)\
break;\
uint8_t * dd = (uint8_t* ) dst; \
uint8_t * ss = (uint8_t* ) src; \
int ll = linesize; \
int ww = width; \
int hh = height; \
for(int i = 0 ; i < hh ; ++i) \
{ \
memcpy(dd, ss, width); \
dd += ww; \
ss += ll; \
} \
}while(0)

#define BEGIN_DISPATCH_MAIN_QUEUE dispatch_async(dispatch_get_main_queue(),^{
#define END_DISPATCH_MAIN_QUEUE });

#define weakSelf(target) __weak typeof(self) target = self;
#define weakReturn(target) __strong typeof(target) strongTarget = target;\
if(strongTarget==nil){return;}

#define SAFE_BLOCK(block,...) if(block) {block(__VA_ARGS__);};

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

#ifndef VIDEO_FRAME
#define VIDEO_FRAME

// 用于表示原始视频数据
struct VideoFrame_ {
    
    uint8_t *luma;          // Y
    uint8_t *chromaB;       // U
    uint8_t *chromaR;       // V
    
    // 视频帧的分辨率 宽高
    int width;
    int height;
    int pixelFormat;// 格式
    
    // 当使用CVOpenGLESTextureCacheRef的缓冲区时该字段有效。此时前面三个字段为NULL
    void *cv_pixelbuffer;
    
    int full_range; // 是否是full range的视频
};
typedef struct VideoFrame_ VideoFrame;
#endif

// 用于表示压缩视频数据
struct _VideoPacket {
    
    uint8_t *data;
    int size;
    int width;
    int height;
};
typedef struct _VideoPacket VideoPacket;

// 用于表示压缩的音频数据
struct _AudioPacket{
    uint8_t *data;
    int     size;
    void *internal;
    int     nb_samples;
    int     time_base;
};
typedef struct _AudioPacket AudioPacket;

#endif /* CommonDefine_h */
